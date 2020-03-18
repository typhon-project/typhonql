package nl.cwi.swat.typhonql.backend.rascal;

import java.util.Map;
import java.util.Objects;

import org.rascalmpl.interpreter.IEvaluatorContext;
import org.rascalmpl.interpreter.result.ICallableValue;
import org.rascalmpl.interpreter.result.ResultFactory;
import org.rascalmpl.interpreter.types.FunctionType;

import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeFactory;
import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.MariaDBEngine;
import nl.cwi.swat.typhonql.backend.ResultStore;

public class MariaDBOperations implements Operations {
	
	Map<String, ConnectionData> connections;
	
	public MariaDBOperations(Map<String, ConnectionData> connections) {
		this.connections = connections;
	}

	private ICallableValue makeExecuteQuery(ResultStore store, Map<String, String> uuids, FunctionType executeType, IEvaluatorContext ctx, IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, executeType, args -> {
			String resultId = ((IString) args[0]).getValue();
			String dbName = ((IString) args[1]).getValue();
			String query = ((IString) args[2]).getValue();
			IMap bindings = (IMap) args[3];
			
			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);
			
			ConnectionData data = connections.get(dbName);
			new MariaDBEngine(store, uuids, data.getHost(), data.getPort(), dbName, data.getUser(), data.getPassword()).executeSelect(resultId, query, bindingsMap);
			
			//sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}
	
	private ICallableValue makeExecuteStatement(ResultStore store, Map<String, String> uuids, FunctionType executeStmtType, IEvaluatorContext ctx, IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, executeStmtType, args -> {
			String dbName = ((IString) args[0]).getValue();
			String query = ((IString) args[1]).getValue();
			IMap bindings = (IMap) args[2];
			
			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);
			
			ConnectionData data = connections.get(dbName);
			new MariaDBEngine(store, uuids, data.getHost(), data.getPort(), dbName, data.getUser(), data.getPassword()).executeUpdate(query, bindingsMap);
			
			//sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}

	public ITuple newSQLOperations(ResultStore store, Map<String, String> uuids, IEvaluatorContext ctx, IValueFactory vf, TypeFactory tf) {
		Type aliasedTuple = Objects.requireNonNull(ctx.getCurrentEnvt().lookupAlias("SQLOperations"));
		while (aliasedTuple.isAliased()) {
			aliasedTuple = aliasedTuple.getAliased();
		}

		FunctionType executeQueryType = (FunctionType)aliasedTuple.getFieldType("executeQuery");
		FunctionType executeStatementType = (FunctionType)aliasedTuple.getFieldType("executeStatement");
				
		return vf.tuple(
            makeExecuteQuery(store, uuids, executeQueryType, ctx, vf, tf),
            makeExecuteStatement(store, uuids, executeStatementType, ctx, vf, tf)
		);
	}
}
