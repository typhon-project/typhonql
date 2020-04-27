package nl.cwi.swat.typhonql.backend.rascal;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Objects;
import java.util.function.Consumer;

import org.rascalmpl.interpreter.IEvaluatorContext;
import org.rascalmpl.interpreter.result.ICallableValue;
import org.rascalmpl.interpreter.result.ResultFactory;
import org.rascalmpl.interpreter.types.FunctionType;

import io.usethesource.vallang.IList;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeFactory;
import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.MariaDBEngine;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;

public class MariaDBOperations implements Operations {

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
            	throw new RuntimeException("Failure to initialize connection to" + dbName, e);
            }
		});
		
	}
	
	private static Connection getConnection(ConnectionData cd, String dbName) throws SQLException {
		return DriverManager.getConnection("jdbc:mariadb://" + cd.getHost() + ":" + cd.getPort() + "/" + dbName + "?user=" + cd.getUser() + "&password=" + cd.getPassword());
	}

	private ICallableValue makeExecuteQuery(ResultStore store, List<Consumer<List<Record>>> script,
			TyphonSessionState state, Map<String, String> uuids, FunctionType executeType, IEvaluatorContext ctx,
			IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, state, executeType, args -> {
			String resultId = ((IString) args[0]).getValue();
			String dbName = ((IString) args[1]).getValue();
			String query = ((IString) args[2]).getValue();
			IMap bindings = (IMap) args[3];
			IList signatureList = (IList) args[4];

			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);
			List<Path> signature = rascalToJavaSignature(signatureList);

			new MariaDBEngine(store, script, uuids, getConnection(dbName, true)).executeSelect(resultId, query, bindingsMap, signature);

			// sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}

	private ICallableValue makeExecuteStatement(ResultStore store, List<Consumer<List<Record>>> script,
			TyphonSessionState state, Map<String, String> uuids, FunctionType executeStmtType, IEvaluatorContext ctx,
			IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, state, executeStmtType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String query = ((IString) args[1]).getValue();
			IMap bindings = (IMap) args[2];

			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);

			new MariaDBEngine(store, script, uuids, getConnection(dbName, true)).executeUpdate(query, bindingsMap);

			// sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}

	private ICallableValue makeExecuteGlobalStatement(ResultStore store, List<Consumer<List<Record>>> script,
			TyphonSessionState state, Map<String, String> uuids, FunctionType executeStmtType, IEvaluatorContext ctx,
			IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, state, executeStmtType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String query = ((IString) args[1]).getValue();
			IMap bindings = (IMap) args[2];

			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);

			new MariaDBEngine(store, script, uuids, getConnection(dbName, false)).executeUpdate(query, bindingsMap);

			// sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}

	public ITuple newSQLOperations(ResultStore store, List<Consumer<List<Record>>> script, TyphonSessionState state,
			Map<String, String> uuids, IEvaluatorContext ctx, IValueFactory vf, TypeFactory tf) {
		Type aliasedTuple = Objects.requireNonNull(ctx.getCurrentEnvt().lookupAlias("SQLOperations"));
		while (aliasedTuple.isAliased()) {
			aliasedTuple = aliasedTuple.getAliased();
		}

		FunctionType executeQueryType = (FunctionType) aliasedTuple.getFieldType("executeQuery");
		FunctionType executeStatementType = (FunctionType) aliasedTuple.getFieldType("executeStatement");
		FunctionType executeGlobalStatementType = (FunctionType) aliasedTuple.getFieldType("executeGlobalStatement");

		return vf.tuple(makeExecuteQuery(store, script, state, uuids, executeQueryType, ctx, vf, tf),
				makeExecuteStatement(store, script, state, uuids, executeStatementType, ctx, vf, tf),
				makeExecuteGlobalStatement(store, script, state, uuids, executeGlobalStatementType, ctx, vf, tf));
	}

	private void initializeDriver() {
		try {
			Class.forName("org.mariadb.jdbc.Driver");
		} catch (ClassNotFoundException e) {
			throw new RuntimeException("MariaDB driver not found", e);
		}
	}

	public void close() {
		String firstFailureDB = null;
		SQLException firstFailure = null;
		for (Entry<String, Connection> conn : connections.entrySet()) {
			try {
				conn.getValue().close();
			} catch (SQLException e) {
				if (firstFailure == null) {
					firstFailure = e;
					firstFailureDB = conn.getKey();
				}
			}
		}
		if (firstFailure != null) {
			throw new RuntimeException("Problems closing connection " + firstFailureDB, firstFailure);
		}

	}
}
