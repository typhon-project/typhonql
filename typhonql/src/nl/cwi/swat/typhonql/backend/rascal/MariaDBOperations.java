/********************************************************************************
* Copyright (c) 2018-2020 CWI & Swat.engineering 
*
* This program and the accompanying materials are made available under the
* terms of the Eclipse Public License 2.0 which is available at
* http://www.eclipse.org/legal/epl-2.0.
*
* This Source Code may also be made available under the following Secondary
* Licenses when the conditions for such availability set forth in the Eclipse
* Public License, v. 2.0 are satisfied: GNU General Public License, version 2
* with the GNU Classpath Exception which is
* available at https://www.gnu.org/software/classpath/license.html.
*
* SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0
********************************************************************************/

package nl.cwi.swat.typhonql.backend.rascal;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.function.BiFunction;
import java.util.function.Consumer;

import org.rascalmpl.interpreter.IEvaluatorContext;
import org.rascalmpl.interpreter.result.ICallableValue;
import org.rascalmpl.interpreter.result.Result;
import org.rascalmpl.interpreter.result.ResultFactory;
import org.rascalmpl.interpreter.types.FunctionType;

import io.usethesource.vallang.IList;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeFactory;
import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.Closables;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.mariadb.MariaDBEngine;

public class MariaDBOperations implements Operations, AutoCloseable {
	
	private static final TypeFactory TF = TypeFactory.getInstance();

	private final Map<String, Connection> connections;
	private final Map<String, ConnectionData> connectionSettings;

	public MariaDBOperations(Map<String, ConnectionData> connections) {
		this.connections = new HashMap<String, Connection>();
		this.connectionSettings = connections;
		initializeDriver();
	}
	
	private Connection getConnection(String dbName, boolean scopedToDb) {
		return connections.computeIfAbsent(scopedToDb ? dbName : "#" + dbName, conName -> {
            ConnectionData settings = connectionSettings.get(dbName);
            if (settings == null) {
                throw new RuntimeException("Missing connection settings for " + dbName);
            }
            try {
                if (scopedToDb) {
                    return getConnection(settings, dbName);
                }
                else {
                    // TODO merge global connection for all databased on the same server
                    return getConnection(settings, "");
                }
            } catch (SQLException e) {
            	throw new RuntimeException("Failure to initialize connection to " + dbName, e);
            }
		});
		
	}
	
	private static Connection getConnection(ConnectionData cd, String dbName) throws SQLException {
		return DriverManager.getConnection("jdbc:mariadb://" + cd.getHost() + ":" + cd.getPort() + "/" + dbName + "?user=" + cd.getUser() + "&password=" + cd.getPassword());
	}

	private ICallableValue makeExecuteQuery(BiFunction<String, Boolean, MariaDBEngine> getEngine, TyphonSessionState state, FunctionType executeType, IEvaluatorContext ctx,
			IValueFactory vf) {
		return makeFunction(ctx, state, executeType, args -> {
			String resultId = ((IString) args[0]).getValue();
			String dbName = ((IString) args[1]).getValue();
			String query = ((IString) args[2]).getValue();
			IMap bindings = (IMap) args[3];
			IList signatureList = (IList) args[4];
			
			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);
			List<Path> signature = rascalToJavaSignature(signatureList);

			getEngine.apply(dbName, true).executeSelect(resultId, query, bindingsMap, signature);
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}

	private ICallableValue makeExecuteStatement(BiFunction<String, Boolean, MariaDBEngine> getEngine, TyphonSessionState state, 
			FunctionType executeStmtType, IEvaluatorContext ctx, IValueFactory vf) {
		return makeFunction(ctx, state, executeStmtType, args -> executeUpdate(getEngine, args, false, ctx));
	}

	private ICallableValue makeExecuteGlobalStatement(BiFunction<String, Boolean, MariaDBEngine> getEngine, TyphonSessionState state, 
			FunctionType executeStmtType, IEvaluatorContext ctx,
			IValueFactory vf) {
		return makeFunction(ctx, state, executeStmtType, args -> executeUpdate(getEngine, args, true, ctx));
	}
	
	private Result<IValue> executeUpdate(BiFunction<String, Boolean, MariaDBEngine> getEngine, IValue[] args, boolean global, IEvaluatorContext ctx) {
        String dbName = ((IString) args[0]).getValue();
        String query = ((IString) args[1]).getValue();
        IMap bindings = (IMap) args[2];

        getEngine.apply(dbName, !global).executeUpdate(query, rascalToJavaBindings(bindings));
        return ResultFactory.makeResult(TF.voidType(), null, ctx);
	}


	public ITuple newSQLOperations(ResultStore store, List<Consumer<List<Record>>> script, List<Runnable> updates, 
			TyphonSessionState state, Map<String, UUID> uuids, IEvaluatorContext ctx, IValueFactory vf) {
		Type aliasedTuple = Objects.requireNonNull(ctx.getCurrentEnvt().lookupAlias("SQLOperations"));
		while (aliasedTuple.isAliased()) {
			aliasedTuple = aliasedTuple.getAliased();
		}

		FunctionType executeQueryType = (FunctionType) aliasedTuple.getFieldType("executeQuery");
		FunctionType executeStatementType = (FunctionType) aliasedTuple.getFieldType("executeStatement");
		FunctionType executeGlobalStatementType = (FunctionType) aliasedTuple.getFieldType("executeGlobalStatement");
		
		BiFunction<String, Boolean, MariaDBEngine> getEngine = (dbName, scoped) -> new MariaDBEngine(store, script, updates, uuids, () -> getConnection(dbName, scoped));

		return vf.tuple(makeExecuteQuery(getEngine, state, executeQueryType, ctx, vf),
				makeExecuteStatement(getEngine, state, executeStatementType, ctx, vf),
				makeExecuteGlobalStatement(getEngine, state, executeGlobalStatementType, ctx, vf));
	}

	private static void initializeDriver() {
		try {
			Class.forName("org.mariadb.jdbc.Driver");
		} catch (ClassNotFoundException e) {
			throw new RuntimeException("MariaDB driver not found", e);
		}
	}

	@Override
	public void close() throws SQLException {
		Closables.autoCloseAll(connections.values(), SQLException.class);
	}
}
