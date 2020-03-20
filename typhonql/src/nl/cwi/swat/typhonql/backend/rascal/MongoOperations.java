package nl.cwi.swat.typhonql.backend.rascal;

import java.util.List;
import java.util.Map;
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
import nl.cwi.swat.typhonql.backend.MongoDBEngine;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;

public class MongoOperations implements Operations {
		
	Map<String, ConnectionData> connections;
	
	public MongoOperations(Map<String, ConnectionData> connections) {
		this.connections = connections;
	}

	private ICallableValue makeFind(ResultStore store, List<Consumer<List<Record>>> script, TyphonSessionState state, Map<String, String> uuids, FunctionType executeType, IEvaluatorContext ctx, IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, state, executeType, args -> {
			String resultId = ((IString) args[0]).getValue();
			String dbName = ((IString) args[1]).getValue();
			String collection = ((IString) args[2]).getValue();
			String query = ((IString) args[3]).getValue();
			IMap bindings = (IMap) args[4];
			IList signatureList = (IList) args[5];
			
			Map<String, Binding> bindingsMap =rascalToJavaBindings(bindings);
			List<Path> signature = rascalToJavaSignature(signatureList);
			
			ConnectionData data = connections.get(dbName);
			new MongoDBEngine(store, script, uuids, data.getHost(), data.getPort(), dbName, data.getUser(), data.getPassword()).executeFind(resultId, collection, query, bindingsMap, signature);
			
			//sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}
	
	private ICallableValue makeFindWithProjection(ResultStore store, List<Consumer<List<Record>>> script, TyphonSessionState state, Map<String, String> uuids, FunctionType executeType, IEvaluatorContext ctx, IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, state, executeType, args -> {
			String resultId = ((IString) args[0]).getValue();
			String dbName = ((IString) args[1]).getValue();
			String collection = ((IString) args[2]).getValue();
			String query = ((IString) args[3]).getValue();
			String projection = ((IString) args[4]).getValue();
			IMap bindings = (IMap) args[5];
			IList signatureList = (IList) args[6];
			
			Map<String, Binding> bindingsMap =rascalToJavaBindings(bindings);
			List<Path> signature = rascalToJavaSignature(signatureList);
			
			ConnectionData data = connections.get(dbName);
			new MongoDBEngine(store, script, uuids, data.getHost(), data.getPort(), dbName, data.getUser(), data.getPassword()).executeFindWithProjection(resultId, collection, query, projection, bindingsMap, signature);
			
			//sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}
	
	private ICallableValue makeInsertOne(ResultStore store, List<Consumer<List<Record>>> script,  TyphonSessionState state, Map<String, String> uuids, FunctionType executeType, IEvaluatorContext ctx, IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, state, executeType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String collection = ((IString) args[1]).getValue();
			String doc = ((IString) args[2]).getValue();
			IMap bindings = (IMap) args[3];
			
			Map<String, Binding> bindingsMap =rascalToJavaBindings(bindings);
			
			ConnectionData data = connections.get(dbName);
			new MongoDBEngine(store, script, uuids, data.getHost(), data.getPort(), dbName, data.getUser(), data.getPassword()).executeInsertOne(dbName, collection, doc, bindingsMap);
			
			//sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}
	
	private ICallableValue makeFindAndUpdateOne(ResultStore store, List<Consumer<List<Record>>> script, TyphonSessionState state, Map<String, String> uuids, FunctionType executeType, IEvaluatorContext ctx, IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, state, executeType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String collection = ((IString) args[1]).getValue();
			String query = ((IString) args[2]).getValue();
			String update = ((IString) args[3]).getValue();
			IMap bindings = (IMap) args[4];
			
			Map<String, Binding> bindingsMap =rascalToJavaBindings(bindings);
			
			ConnectionData data = connections.get(dbName);
			new MongoDBEngine(store, script, uuids, data.getHost(), data.getPort(), dbName, data.getUser(), data.getPassword()).executeFindAndUpdateOne(dbName, collection, query, update, bindingsMap);
			
			//sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}
	
	
	private ICallableValue makeDeleteOne(ResultStore store, List<Consumer<List<Record>>> script, TyphonSessionState state, Map<String, String> uuids, FunctionType executeType, IEvaluatorContext ctx, IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, state, executeType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String collection = ((IString) args[1]).getValue();
			String query = ((IString) args[2]).getValue();
			IMap bindings = (IMap) args[3];
			
			Map<String, Binding> bindingsMap =rascalToJavaBindings(bindings);
			
			ConnectionData data = connections.get(dbName);
			new MongoDBEngine(store, script, uuids, data.getHost(), data.getPort(), dbName, data.getUser(), data.getPassword()).executeDeleteOne(dbName, collection, query, bindingsMap);
			
			//sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}
	
	public ITuple newMongoOperations(ResultStore store, List<Consumer<List<Record>>> script, TyphonSessionState state, Map<String, String> uuids, IEvaluatorContext ctx, IValueFactory vf, TypeFactory tf) {
		
		Type aliasedTuple = Objects.requireNonNull(ctx.getCurrentEnvt().lookupAlias("MongoOperations"));
		while (aliasedTuple.isAliased()) {
			aliasedTuple = aliasedTuple.getAliased();
		}
		// get the function types
		FunctionType executeType1 = (FunctionType)aliasedTuple.getFieldType("find");
		FunctionType executeType2 = (FunctionType)aliasedTuple.getFieldType("findWithProjection");
		FunctionType executeType3 = (FunctionType)aliasedTuple.getFieldType("insertOne");
		FunctionType executeType4 = (FunctionType)aliasedTuple.getFieldType("findAndUpdateOne");
		FunctionType executeType5 = (FunctionType)aliasedTuple.getFieldType("deleteOne");
		
		return vf.tuple(
            makeFind(store, script, state, uuids, executeType1, ctx, vf, tf),
            makeFindWithProjection(store, script, state, uuids, executeType2, ctx, vf, tf),
            makeInsertOne(store, script, state, uuids, executeType3, ctx, vf, tf),
            makeFindAndUpdateOne(store, script, state, uuids, executeType4, ctx, vf, tf),
            makeDeleteOne(store, script, state, uuids, executeType5, ctx, vf, tf)
		);
	}
}
