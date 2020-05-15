package nl.cwi.swat.typhonql.backend.rascal;

import java.net.URISyntaxException;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.function.Consumer;

import org.rascalmpl.interpreter.IEvaluatorContext;
import org.rascalmpl.interpreter.result.ResultFactory;
import org.rascalmpl.interpreter.types.FunctionType;
import org.rascalmpl.interpreter.utils.RuntimeExceptionFactory;

import io.usethesource.vallang.IList;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeFactory;
import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.NLPEngine;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;

public class NLPOperations implements Operations {
	
	private ConnectionData connection;

	public NLPOperations(ConnectionData data) {
		this.connection = data;
	}
	private NLPEngine engine(ResultStore store, List<Consumer<List<Record>>> script, List<Runnable> updates,
			Map<String, String> uuids) throws URISyntaxException {
		return new NLPEngine(store, script, updates, uuids, connection);
	}

	public ITuple newNLPOperations(ResultStore store, List<Consumer<List<Record>>> script, List<Runnable> updates,
			TyphonSessionState state, Map<String, String> uuids, IEvaluatorContext ctx, IValueFactory vf,
			TypeFactory tf) {

		Type aliasedTuple = Objects.requireNonNull(ctx.getCurrentEnvt().lookupAlias("NLPOperations"));
		while (aliasedTuple.isAliased()) {
			aliasedTuple = aliasedTuple.getAliased();
		}
		// get the function types
		FunctionType executeType1 = (FunctionType) aliasedTuple.getFieldType("sendRequests");
		return vf.tuple(makeSendRequests(store, script, updates, state, uuids, executeType1, ctx, vf, tf));
	}

	private IValue makeSendRequests(ResultStore store, List<Consumer<List<Record>>> script, List<Runnable> updates,
			TyphonSessionState state, Map<String, String> uuids, FunctionType executeType, IEvaluatorContext ctx,
			IValueFactory vf, TypeFactory tf) {
		return makeFunction(ctx, state, executeType, args -> {
			IList requests = (IList) args[0];
			IMap bindings = (IMap) args[1];
			
			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);

			try {
				engine(store, script, updates, uuids).sendRequests(requests, bindingsMap);
			} catch (URISyntaxException e) {
				RuntimeExceptionFactory.javaException(e, null, null);
			}

			// sessionData.put(resultName, query);
			return ResultFactory.makeResult(tf.voidType(), null, ctx);
		});
	}

}
