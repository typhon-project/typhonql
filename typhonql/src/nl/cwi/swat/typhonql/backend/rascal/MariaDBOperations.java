package nl.cwi.swat.typhonql.backend.rascal;

import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.Objects;
import java.util.Map.Entry;

import org.rascalmpl.interpreter.IEvaluatorContext;
import org.rascalmpl.interpreter.result.ICallableValue;
import org.rascalmpl.interpreter.result.ResultFactory;
import org.rascalmpl.interpreter.types.FunctionType;

import io.usethesource.vallang.IInteger;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeFactory;
import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.MariaDBEngine;
import nl.cwi.swat.typhonql.backend.ResultStore;

public class MariaDBOperations implements Operations {
	
	private ICallableValue makeExecuteQuery(ResultStore store, FunctionType executeType, IEvaluatorContext ctx, IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, executeType, args -> {
			String resultId = ((IString) args[0]).getValue();
			String host = ((IString) args[1]).getValue();
			int port = ((IInteger) args[2]).intValue();
			String user = ((IString) args[3]).getValue();
			String password = ((IString) args[4]).getValue();
			String dbName = ((IString) args[5]).getValue();
			String query = ((IString) args[6]).getValue();
			IMap bindings = (IMap) args[7];
			
			Iterator<Entry<IValue, IValue>> iter = bindings.entryIterator();
			
			Map<String, Binding> bindingsMap = new HashMap<>();
			
			while (iter.hasNext()) {
				Entry<IValue, IValue> kv = iter.next();
				IString param = (IString) kv.getKey();
				ITuple field = (ITuple) kv.getValue();
				Binding b = new Binding(((IString) field.get(0)).getValue() ,
						((IString) field.get(1)).getValue(), ((IString) field.get(2)).getValue());
				bindingsMap.put(param.getValue(), b);
			}
			
			new MariaDBEngine(store, host, port, dbName, user, password).executeSelect(resultId, query, bindingsMap);
			
			//sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}
	
	public ITuple newSQLOperations(ResultStore store, IEvaluatorContext ctx, IValueFactory vf, TypeFactory tf) {
		Type aliasedTuple = Objects.requireNonNull(ctx.getCurrentEnvt().lookupAlias("SQLOperations"));
		while (aliasedTuple.isAliased()) {
			aliasedTuple = aliasedTuple.getAliased();
		}

		FunctionType executeType = (FunctionType)aliasedTuple.getFieldType("executeQuery");
				
		return vf.tuple(
            makeExecuteQuery(store, executeType, ctx, vf, tf)
		);
	}
}
