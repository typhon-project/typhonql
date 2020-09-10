package nl.cwi.swat.typhonql.backend.rascal;

import java.sql.SQLException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.function.Consumer;
import java.util.function.Function;

import org.neo4j.driver.AuthTokens;
import org.neo4j.driver.Driver;
import org.neo4j.driver.GraphDatabase;
import org.neo4j.driver.exceptions.Neo4jException;
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
import nl.cwi.swat.typhonql.backend.Closables;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.neo4j.Neo4JEngine;

public class Neo4JOperations implements Operations, AutoCloseable {

	private static final TypeFactory TF = TypeFactory.getInstance();

	private final Map<String, Driver> connections;
	private final Map<String, ConnectionData> connectionSettings;

	public Neo4JOperations(Map<String, ConnectionData> connections) {
		this.connections = new HashMap<String, Driver>();
		this.connectionSettings = connections;
	}

	private Driver getConnection(String dbName, boolean scopedToDb) {
		return connections.computeIfAbsent(scopedToDb ? dbName : "#" + dbName, conName -> {
			ConnectionData settings = connectionSettings.get(dbName);
			if (settings == null) {
				throw new RuntimeException("Missing connection settings for " + dbName);
			}
			try {
				return getConnection(settings, dbName);
			} catch (SQLException e) {
				throw new RuntimeException("Failure to initialize connection to" + dbName, e);
			}
		});

	}

	private static Driver getConnection(ConnectionData cd, String dbName) throws SQLException {
		// TODO dbName being ignored
		return GraphDatabase.driver("bolt://" + cd.getHost() + ":" + cd.getPort(),
				AuthTokens.basic(cd.getUser(), cd.getPassword()));
	}
	
	private ICallableValue makeExecuteMatch(Function<String, Neo4JEngine> getEngine,
			TyphonSessionState state, FunctionType executeType, IEvaluatorContext ctx, IValueFactory vf) {
		return makeFunction(ctx, state, executeType, args -> {
			String resultId = ((IString) args[0]).getValue();
			String dbName = ((IString) args[1]).getValue();
			String query = ((IString) args[2]).getValue();
			IMap bindings = (IMap) args[3];
			IList signatureList = (IList) args[4];

			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);
			List<Path> signature = rascalToJavaSignature(signatureList);

			getEngine.apply(dbName).executeMatch(resultId, query, bindingsMap, signature);
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}
	
	private ICallableValue makeExecuteUpdate(Function<String, Neo4JEngine> getEngine,
			TyphonSessionState state, FunctionType executeType, IEvaluatorContext ctx, IValueFactory vf) {
		return makeFunction(ctx, state, executeType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String query = ((IString) args[1]).getValue();
			IMap bindings = (IMap) args[2];

			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);
			
			getEngine.apply(dbName).executeUpdate(query, bindingsMap);
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}
	
	public ITuple newNeo4JOperations(ResultStore store, List<Consumer<List<Record>>> script, TyphonSessionState state, 
			Map<String, UUID> uuids, IEvaluatorContext ctx, IValueFactory vf) {
		Type aliasedTuple = Objects.requireNonNull(ctx.getCurrentEnvt().lookupAlias("Neo4JOperations"));
		while (aliasedTuple.isAliased()) {
			aliasedTuple = aliasedTuple.getAliased();
		}

		FunctionType executeMatchType = (FunctionType) aliasedTuple.getFieldType("executeMatch");
		FunctionType executeUpdateType = (FunctionType) aliasedTuple.getFieldType("executeUpdate");
		
		Function<String, Neo4JEngine> getEngine = 
				(dbName) ->
					new Neo4JEngine(store, script, uuids, getConnection(dbName, true));

		return vf.tuple(makeExecuteMatch(getEngine, state, executeMatchType, ctx, vf),
				makeExecuteUpdate(getEngine, state, executeUpdateType, ctx, vf));
	}

	

	@Override
	public void close() throws Exception {
		Closables.autoCloseAll(connections.values(), Neo4jException.class);
	}
}
