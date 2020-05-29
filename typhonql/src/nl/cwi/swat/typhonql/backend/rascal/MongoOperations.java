package nl.cwi.swat.typhonql.backend.rascal;

import java.sql.SQLException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.function.Consumer;
import java.util.function.Function;
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
import nl.cwi.swat.typhonql.backend.Closables;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.mongodb.MongoDBEngine;

public class MongoOperations implements Operations, AutoCloseable {

	private static final TypeFactory TF = TypeFactory.getInstance();

	private final Map<String, MongoDatabase> connections;
	private final Map<String, MongoClient> clients;
	private final Map<String, ConnectionData> connectionSettings;

	public MongoOperations(Map<String, ConnectionData> connections) {
		this.connections = new HashMap<>();
		this.clients = new HashMap<>();
		this.connectionSettings = connections;
	}

	private MongoDatabase getDatabase(String dbName) {
		return connections.computeIfAbsent(dbName, nm -> {
			ConnectionData cd = connectionSettings.get(nm);
			if (cd == null) {
				throw new RuntimeException("Missing database config for " + nm);
			}
			MongoClient client = clients.computeIfAbsent(cd.getHost(), h -> MongoClients.create(
					"mongodb://" + cd.getUser() + ":" + cd.getPassword() + "@" + cd.getHost() + ":" + cd.getPort()));
			return client.getDatabase(nm);
		});
	}

	private ICallableValue makeFind(Function<String, MongoDBEngine> engine, TyphonSessionState state, FunctionType executeType, IEvaluatorContext ctx,
			IValueFactory vf) {
		return makeFunction(ctx, state, executeType, args -> {
			String resultId = ((IString) args[0]).getValue();
			String dbName = ((IString) args[1]).getValue();
			String collection = ((IString) args[2]).getValue();
			String query = ((IString) args[3]).getValue();
			IMap bindings = (IMap) args[4];
			IList signatureList = (IList) args[5];

			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);
			List<Path> signature = rascalToJavaSignature(signatureList);

			engine.apply(dbName).executeFind(resultId, collection, query, bindingsMap, signature);

			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}

	private ICallableValue makeFindWithProjection(Function<String, MongoDBEngine> engine, TyphonSessionState state, FunctionType executeType,
			IEvaluatorContext ctx, IValueFactory vf) {
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

			engine.apply(dbName).executeFindWithProjection(resultId, collection, query, projection, bindingsMap, signature);

			// sessionData.put(resultName, query);
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}

	private ICallableValue makeInsertOne(Function<String, MongoDBEngine> engine, TyphonSessionState state, 
			FunctionType executeType, IEvaluatorContext ctx,
			IValueFactory vf) {
		return makeFunction(ctx, state, executeType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String collection = ((IString) args[1]).getValue();
			String doc = ((IString) args[2]).getValue();
			IMap bindings = (IMap) args[3];

			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);

			engine.apply(dbName).executeInsertOne(dbName, collection, doc, bindingsMap);

			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}

	private ICallableValue makeFindAndUpdateOne(Function<String, MongoDBEngine> engine, TyphonSessionState state,
			FunctionType executeType, IEvaluatorContext ctx, IValueFactory vf) {
		return makeFunction(ctx, state, executeType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String collection = ((IString) args[1]).getValue();
			String query = ((IString) args[2]).getValue();
			String update = ((IString) args[3]).getValue();
			IMap bindings = (IMap) args[4];

			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);

			engine.apply(dbName).executeFindAndUpdateOne(dbName, collection, query, update,
					bindingsMap);

			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}
	
	private ICallableValue makeFindAndUpdateMany(Function<String, MongoDBEngine> engine, TyphonSessionState state, 
			FunctionType executeType, IEvaluatorContext ctx, IValueFactory vf) {
		return makeFunction(ctx, state, executeType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String collection = ((IString) args[1]).getValue();
			String query = ((IString) args[2]).getValue();
			String update = ((IString) args[3]).getValue();
			IMap bindings = (IMap) args[4];

			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);

			engine.apply(dbName).executeFindAndUpdateMany(dbName, collection, query, update, bindingsMap);

			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}

	private ICallableValue makeDeleteOne(Function<String, MongoDBEngine> engine, TyphonSessionState state, 
			FunctionType executeType, IEvaluatorContext ctx, IValueFactory vf) {
		return makeFunction(ctx, state, executeType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String collection = ((IString) args[1]).getValue();
			String query = ((IString) args[2]).getValue();
			IMap bindings = (IMap) args[3];

			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);

			engine.apply(dbName).executeDeleteOne(dbName, collection, query, bindingsMap);
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}
	
	private ICallableValue makeDeleteMany(Function<String, MongoDBEngine> engine, TyphonSessionState state, 
			FunctionType executeType, IEvaluatorContext ctx, IValueFactory vf) {
		return makeFunction(ctx, state, executeType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String collection = ((IString) args[1]).getValue();
			String query = ((IString) args[2]).getValue();
			IMap bindings = (IMap) args[3];

			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);

			engine.apply(dbName).executeDeleteMany(dbName, collection, query, bindingsMap);
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}

	private ICallableValue makeCreateIndex(Function<String, MongoDBEngine> engine, TyphonSessionState state, 
			FunctionType executeType, IEvaluatorContext ctx, IValueFactory vf) {
		return makeFunction(ctx, state, executeType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String collection = ((IString) args[1]).getValue();
			String selector = ((IString) args[2]).getValue();
			String index = ((IString) args[3]).getValue();

			engine.apply(dbName).executeCreateIndex(collection, selector, index);
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}
	
	private ICallableValue makeCreateCollection(Function<String, MongoDBEngine> engine, TyphonSessionState state, FunctionType executeType,
			IEvaluatorContext ctx, IValueFactory vf) {
		return makeFunction(ctx, state, executeType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String collection = ((IString) args[1]).getValue();

			engine.apply(dbName).executeCreateCollection(dbName, collection);

			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}

	private ICallableValue makeRenameCollection(Function<String, MongoDBEngine> engine, TyphonSessionState state, 
			FunctionType executeType, IEvaluatorContext ctx, IValueFactory vf) {
		return makeFunction(ctx, state, executeType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String collection = ((IString) args[1]).getValue();
			String newName = ((IString) args[2]).getValue();

			engine.apply(dbName).executeRenameCollection(dbName, collection, newName);

			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}

	private ICallableValue makeDropCollection(Function<String, MongoDBEngine> engine, TyphonSessionState state, 
			FunctionType executeType, IEvaluatorContext ctx, IValueFactory vf) {
		return makeFunction(ctx, state, executeType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String collection = ((IString) args[1]).getValue();

			engine.apply(dbName).executeDropCollection(dbName, collection);

			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}

	private ICallableValue makeDropDatabase(Function<String, MongoDBEngine> engine, TyphonSessionState state, 
			FunctionType executeType, IEvaluatorContext ctx, IValueFactory vf) {
		return makeFunction(ctx, state, executeType, args -> {
			String dbName = ((IString) args[0]).getValue();

			engine.apply(dbName).executeDropDatabase(dbName);

			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}

	
	private static FunctionType func(Type source, String name) {
		return (FunctionType) source.getFieldType(name);
	}
	
	public ITuple newMongoOperations(ResultStore store, List<Consumer<List<Record>>> script, List<Runnable> updates,
			TyphonSessionState state, Map<String, String> uuids, IEvaluatorContext ctx, IValueFactory vf) {

		Type aliasedTuple = Objects.requireNonNull(ctx.getCurrentEnvt().lookupAlias("MongoOperations"));
		while (aliasedTuple.isAliased()) {
			aliasedTuple = aliasedTuple.getAliased();
		}

		Function<String, MongoDBEngine> getEngine = dbName -> new MongoDBEngine(store, script, updates, uuids, getDatabase(dbName));

		return vf.tuple(makeFind(getEngine, state, func(aliasedTuple, "find"), ctx, vf),
				makeFindWithProjection(getEngine, state, func(aliasedTuple, "findWithProjection"), ctx, vf),
				makeInsertOne(getEngine, state, func(aliasedTuple, "insertOne"), ctx, vf),
				makeFindAndUpdateOne(getEngine, state, func(aliasedTuple, "findAndUpdateOne"), ctx, vf),
				makeFindAndUpdateMany(getEngine, state, func(aliasedTuple, "findAndUpdateMany"), ctx, vf),
				makeDeleteOne(getEngine, state, func(aliasedTuple, "deleteOne"), ctx, vf),
				makeDeleteMany(getEngine, state, func(aliasedTuple, "deleteMany"), ctx, vf),
				makeCreateCollection(getEngine, state, func(aliasedTuple, "createCollection"), ctx, vf),
				makeCreateIndex(getEngine, state, func(aliasedTuple, "createIndex"), ctx, vf),
				makeRenameCollection(getEngine, state, func(aliasedTuple, "renameCollection"), ctx, vf),
				makeDropCollection(getEngine, state, func(aliasedTuple, "dropCollection"), ctx, vf),
				makeDropDatabase(getEngine, state, func(aliasedTuple, "dropDatabase"), ctx, vf));
	}


	@Override
	public void close() {
		Closables.closeAll(clients.values(), RuntimeException.class);
	}
}
