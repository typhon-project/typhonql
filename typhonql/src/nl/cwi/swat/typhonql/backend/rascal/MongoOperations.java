package nl.cwi.swat.typhonql.backend.rascal;

import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Objects;

import org.rascalmpl.interpreter.IEvaluatorContext;
import org.rascalmpl.interpreter.result.ICallableValue;
import org.rascalmpl.interpreter.result.ResultFactory;
import org.rascalmpl.interpreter.types.FunctionType;

import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeFactory;
import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.MongoDBEngine;
import nl.cwi.swat.typhonql.backend.ResultStore;

public class MongoOperations implements Operations {
		
	Map<String, ConnectionData> connections;
	
	public MongoOperations(Map<String, ConnectionData> connections) {
		this.connections = connections;
	}

	private ICallableValue makeFind(ResultStore store, FunctionType executeType, IEvaluatorContext ctx, IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, executeType, args -> {
			String resultId = ((IString) args[0]).getValue();
			String dbName = ((IString) args[1]).getValue();
			String collection = ((IString) args[2]).getValue();
			String query = ((IString) args[3]).getValue();
			IMap bindings = (IMap) args[4];
			
			Iterator<Entry<IValue, IValue>> iter = bindings.entryIterator();
			
			LinkedHashMap<String, Binding> bindingsMap = new LinkedHashMap<>();
			
			while (iter.hasNext()) {
				Entry<IValue, IValue> kv = iter.next();
				IString param = (IString) kv.getKey();
				ITuple field = (ITuple) kv.getValue();
				Binding b = new Binding(((IString) field.get(0)).getValue() ,
						((IString) field.get(1)).getValue(), ((IString) field.get(2)).getValue(), ((IString) field.get(3)).getValue());
				bindingsMap.put(param.getValue(), b);
			}
			
			ConnectionData data = connections.get(dbName);
			new MongoDBEngine(store, data.getHost(), data.getPort(), dbName, data.getUser(), data.getPassword()).executeFind(resultId, collection, query, bindingsMap);
			
			//sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}
	
	private ICallableValue makeFindWithProjection(ResultStore store, FunctionType executeType, IEvaluatorContext ctx, IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, executeType, args -> {
			String resultId = ((IString) args[0]).getValue();
			String dbName = ((IString) args[1]).getValue();
			String collection = ((IString) args[2]).getValue();
			String query = ((IString) args[3]).getValue();
			String projection = ((IString) args[4]).getValue();
			IMap bindings = (IMap) args[5];
			
			Iterator<Entry<IValue, IValue>> iter = bindings.entryIterator();
			
			LinkedHashMap<String, Binding> bindingsMap = new LinkedHashMap<>();
			
			while (iter.hasNext()) {
				Entry<IValue, IValue> kv = iter.next();
				IString param = (IString) kv.getKey();
				ITuple field = (ITuple) kv.getValue();
				Binding b = new Binding(((IString) field.get(0)).getValue() ,
						((IString) field.get(1)).getValue(), ((IString) field.get(2)).getValue(), ((IString) field.get(3)).getValue());
				bindingsMap.put(param.getValue(), b);
			}
			
			ConnectionData data = connections.get(dbName);
			new MongoDBEngine(store, data.getHost(), data.getPort(), dbName, data.getUser(), data.getPassword()).executeFindWithProjection(resultId, collection, query, projection, bindingsMap);
			
			//sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}
	
	public ITuple newMongoOperations(ResultStore store, IEvaluatorContext ctx, IValueFactory vf, TypeFactory tf) {
		
		Type aliasedTuple = Objects.requireNonNull(ctx.getCurrentEnvt().lookupAlias("MongoOperations"));
		while (aliasedTuple.isAliased()) {
			aliasedTuple = aliasedTuple.getAliased();
		}
		// get the function types
		FunctionType executeType1 = (FunctionType)aliasedTuple.getFieldType("find");
		FunctionType executeType2 = (FunctionType)aliasedTuple.getFieldType("findWithProjection");
		
		return vf.tuple(
            makeFind(store, executeType1, ctx, vf, tf),
            makeFindWithProjection(store, executeType2, ctx, vf, tf)
		);
	}
}
