package nl.cwi.swat.typhonql.backend.rascal;

import java.util.ArrayList;
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

import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import com.mongodb.client.MongoDatabase;

import io.usethesource.vallang.IList;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeFactory;
import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.MongoDBEngine;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;

public class MongoOperations implements Operations {

	private final Map<String, MongoDatabase> connections;
	private final List<MongoClient> clients;

	public MongoOperations(Map<String, ConnectionData> connections) {
		this.connections = new HashMap<String, MongoDatabase>();
		this.clients = new ArrayList<>();
		for (Entry<String, ConnectionData> entry : connections.entrySet()) {
			String dbName = entry.getKey();
			ConnectionData data = entry.getValue();
			MongoClient currentClient = MongoClients
					.create(getConnectionString(data.getHost(), data.getPort(), data.getUser(), data.getPassword()));
			MongoDatabase conn = currentClient.getDatabase(dbName);
			this.clients.add(currentClient);
			this.connections.put(dbName, conn);
		}
	}

	private String getConnectionString(String host, int port, String user, String password) {
		return "mongodb://" + user + ":" + password + "@" + host + ":" + port;
	}

	private ICallableValue makeFind(ResultStore store, List<Consumer<List<Record>>> script, TyphonSessionState state,
			Map<String, String> uuids, FunctionType executeType, IEvaluatorContext ctx, IValueFactory vf,
			TypeFactory tf) {
		return makeFunction(ctx, state, executeType, args -> {
			String resultId = ((IString) args[0]).getValue();
			String dbName = ((IString) args[1]).getValue();
			String collection = ((IString) args[2]).getValue();
			String query = ((IString) args[3]).getValue();
			IMap bindings = (IMap) args[4];
			IList signatureList = (IList) args[5];

			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);
			List<Path> signature = rascalToJavaSignature(signatureList);

			MongoDatabase conn = connections.get(dbName);
			new MongoDBEngine(store, script, uuids, conn).executeFind(resultId, collection, query, bindingsMap,
					signature);

			// sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}

	private ICallableValue makeFindWithProjection(ResultStore store, List<Consumer<List<Record>>> script,
			TyphonSessionState state, Map<String, String> uuids, FunctionType executeType, IEvaluatorContext ctx,
			IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, state, executeType, args -> {
			String resultId = ((IString) args[0]).getValue();
			String dbName = ((IString) args[1]).getValue();
			String collection = ((IString) args[2]).getValue();
			String query = ((IString) args[3]).getValue();
			String projection = ((IString) args[4]).getValue();
			IMap bindings = (IMap) args[5];
			IList signatureList = (IList) args[6];

			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);
			List<Path> signature = rascalToJavaSignature(signatureList);

			MongoDatabase conn = connections.get(dbName);
			new MongoDBEngine(store, script, uuids, conn).executeFindWithProjection(resultId, collection, query,
					projection, bindingsMap, signature);

			// sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}

	private ICallableValue makeInsertOne(ResultStore store, List<Consumer<List<Record>>> script,
			TyphonSessionState state, Map<String, String> uuids, FunctionType executeType, IEvaluatorContext ctx,
			IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, state, executeType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String collection = ((IString) args[1]).getValue();
			String doc = ((IString) args[2]).getValue();
			IMap bindings = (IMap) args[3];

			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);

			MongoDatabase conn = connections.get(dbName);
			new MongoDBEngine(store, script, uuids, conn).executeInsertOne(dbName, collection, doc, bindingsMap);

			// sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}

	private ICallableValue makeFindAndUpdateOne(ResultStore store, List<Consumer<List<Record>>> script,
			TyphonSessionState state, Map<String, String> uuids, FunctionType executeType, IEvaluatorContext ctx,
			IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, state, executeType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String collection = ((IString) args[1]).getValue();
			String query = ((IString) args[2]).getValue();
			String update = ((IString) args[3]).getValue();
			IMap bindings = (IMap) args[4];

			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);

			MongoDatabase conn = connections.get(dbName);
			new MongoDBEngine(store, script, uuids, conn).executeFindAndUpdateOne(dbName, collection, query, update,
					bindingsMap);

			// sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}

	private ICallableValue makeDeleteOne(ResultStore store, List<Consumer<List<Record>>> script,
			TyphonSessionState state, Map<String, String> uuids, FunctionType executeType, IEvaluatorContext ctx,
			IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, state, executeType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String collection = ((IString) args[1]).getValue();
			String query = ((IString) args[2]).getValue();
			IMap bindings = (IMap) args[3];

			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);

			MongoDatabase conn = connections.get(dbName);
			new MongoDBEngine(store, script, uuids, conn).executeDeleteOne(dbName, collection, query, bindingsMap);

			// sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}

	private ICallableValue makeCreateCollection(ResultStore store, List<Consumer<List<Record>>> script,
			TyphonSessionState state, Map<String, String> uuids, FunctionType executeType, IEvaluatorContext ctx,
			IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, state, executeType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String collection = ((IString) args[1]).getValue();

			MongoDatabase conn = connections.get(dbName);
			new MongoDBEngine(store, script, uuids, conn).executeCreateCollection(dbName, collection);

			// sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}
	
	private ICallableValue makeRenameCollection(ResultStore store, List<Consumer<List<Record>>> script,
			TyphonSessionState state, Map<String, String> uuids, FunctionType executeType, IEvaluatorContext ctx,
			IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, state, executeType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String collection = ((IString) args[1]).getValue();
			String newName = ((IString) args[2]).getValue();

			MongoDatabase conn = connections.get(dbName);
			new MongoDBEngine(store, script, uuids, conn).executeRenameCollection(dbName, collection, newName);

			// sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}


	private ICallableValue makeDropCollection(ResultStore store, List<Consumer<List<Record>>> script,
			TyphonSessionState state, Map<String, String> uuids, FunctionType executeType, IEvaluatorContext ctx,
			IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, state, executeType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String collection = ((IString) args[1]).getValue();

			MongoDatabase conn = connections.get(dbName);
			new MongoDBEngine(store, script, uuids, conn).executeDropCollection(dbName, collection);

			// sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}

	private ICallableValue makeDropDatabase(ResultStore store, List<Consumer<List<Record>>> script,
			TyphonSessionState state, Map<String, String> uuids, FunctionType executeType, IEvaluatorContext ctx,
			IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, state, executeType, args -> {
			String dbName = ((IString) args[0]).getValue();

			MongoDatabase conn = connections.get(dbName);
			new MongoDBEngine(store, script, uuids, conn).executeDropDatabase(dbName);

			// sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}

	public ITuple newMongoOperations(ResultStore store, List<Consumer<List<Record>>> script, TyphonSessionState state,
			Map<String, String> uuids, IEvaluatorContext ctx, IValueFactory vf, TypeFactory tf) {

		Type aliasedTuple = Objects.requireNonNull(ctx.getCurrentEnvt().lookupAlias("MongoOperations"));
		while (aliasedTuple.isAliased()) {
			aliasedTuple = aliasedTuple.getAliased();
		}
		// get the function types
		FunctionType executeType1 = (FunctionType) aliasedTuple.getFieldType("find");
		FunctionType executeType2 = (FunctionType) aliasedTuple.getFieldType("findWithProjection");
		FunctionType executeType3 = (FunctionType) aliasedTuple.getFieldType("insertOne");
		FunctionType executeType4 = (FunctionType) aliasedTuple.getFieldType("findAndUpdateOne");
		FunctionType executeType5 = (FunctionType) aliasedTuple.getFieldType("deleteOne");
		FunctionType executeType6 = (FunctionType) aliasedTuple.getFieldType("createCollection");
		FunctionType executeType7 = (FunctionType) aliasedTuple.getFieldType("renameCollection");
		FunctionType executeType8 = (FunctionType) aliasedTuple.getFieldType("dropCollection");
		FunctionType executeType9 = (FunctionType) aliasedTuple.getFieldType("dropDatabase");

		return vf.tuple(makeFind(store, script, state, uuids, executeType1, ctx, vf, tf),
				makeFindWithProjection(store, script, state, uuids, executeType2, ctx, vf, tf),
				makeInsertOne(store, script, state, uuids, executeType3, ctx, vf, tf),
				makeFindAndUpdateOne(store, script, state, uuids, executeType4, ctx, vf, tf),
				makeDeleteOne(store, script, state, uuids, executeType5, ctx, vf, tf),
				makeCreateCollection(store, script, state, uuids, executeType6, ctx, vf, tf),
				makeRenameCollection(store, script, state, uuids, executeType7, ctx, vf, tf),
				makeDropCollection(store, script, state, uuids, executeType8, ctx, vf, tf),
				makeDropDatabase(store, script, state, uuids, executeType9, ctx, vf, tf));
	}

	public void close() {
		Exception failed = null;
		for (MongoClient c: clients) {
			try {
				c.close();
			}
			catch (Exception e) {
				if (failed == null) {
					failed =e;
				}
			}
		}
		if (failed != null) {
			throw new RuntimeException("Failure closing mongo clients", failed);
		}
	}
}
