package nl.cwi.swat.typhonql.backend.nlp;

import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.function.Consumer;
import java.util.function.Supplier;

import org.rascalmpl.interpreter.IEvaluatorContext;
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
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.rascal.ConnectionData;
import nl.cwi.swat.typhonql.backend.rascal.Operations;
import nl.cwi.swat.typhonql.backend.rascal.Path;
import nl.cwi.swat.typhonql.backend.rascal.TyphonSessionState;

public class NlpOperations implements Operations, AutoCloseable{
	
	private static final String NLP_KEY = "nlae";
	private static final String NLP_DEFAULT_HOST = "localhost";
	private static final int NLP_DEFAULT_PORT = 8888;
	
	
	private static final TypeFactory TF = TypeFactory.getInstance();

	private final String host;
	private final int port;
	private final String user;
	private final String password;
	
	public NlpOperations(Map<String, ConnectionData> connections) {
		if (connections.containsKey(NLP_KEY)) {
			ConnectionData cd = connections.get(NLP_KEY);
			host = cd.getHost();
			port = cd.getPort();
			user = cd.getPassword();
			password = cd.getPassword();
		}
		else {
			// Default values for testing
			// TODO remove
			host = NLP_DEFAULT_HOST;
			port = NLP_DEFAULT_PORT;
			user = null;
			password = null;
			//throw new RuntimeException("Problems initializing Nlp operations. Missing connection information");
		}
		
	}
	
	public ITuple newNlpOperations(ResultStore store, List<Consumer<List<Record>>> script, TyphonSessionState state, 
			Map<String, UUID> uuids, IEvaluatorContext ctx, IValueFactory vf) {
		Type aliasedTuple = Objects.requireNonNull(ctx.getCurrentEnvt().lookupAlias("NlpOperations"));
		while (aliasedTuple.isAliased()) {
			aliasedTuple = aliasedTuple.getAliased();
		}

		FunctionType processType = (FunctionType) aliasedTuple.getFieldType("process");
		FunctionType deleteType = (FunctionType) aliasedTuple.getFieldType("delete");
		FunctionType queryType = (FunctionType) aliasedTuple.getFieldType("query");
		
		Supplier<NlpEngine> getEngine = () -> new NlpEngine(store, state, script, uuids, host, port, user, password);

		return vf.tuple(makeProcess(getEngine, state, processType, ctx, vf),
				makeDelete(getEngine, state, deleteType, ctx, vf),
				makeQuery(getEngine, state, queryType, ctx, vf));
	}

	private IValue makeQuery(Supplier<NlpEngine> getEngine, TyphonSessionState state, FunctionType queryType,
			IEvaluatorContext ctx, IValueFactory vf) {
		return makeFunction(ctx, state, queryType, args -> {
			String query = ((IString) args[0]).getValue();
			IMap bindings = (IMap) args[1];
			IList signatureList = (IList) args[2];
			
			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);
			List<Path> signature = rascalToJavaSignature(signatureList);
			
			getEngine.get().query(query, bindingsMap, signature);
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}

	private IValue makeProcess(Supplier<NlpEngine> getEngine, TyphonSessionState state, FunctionType processType, IEvaluatorContext ctx,
			IValueFactory vf) {
		return makeFunction(ctx, state, processType, args -> {
			String query = ((IString) args[0]).getValue();
			IMap bindings = (IMap) args[1];

			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);
			
			getEngine.get().process(query, bindingsMap);
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}
	
	private IValue makeDelete(Supplier<NlpEngine> getEngine, TyphonSessionState state, FunctionType deleteType, IEvaluatorContext ctx,
			IValueFactory vf) {
		return makeFunction(ctx, state, deleteType, args -> {
			String query = ((IString) args[0]).getValue();
			IMap bindings = (IMap) args[1];

			Map<String, Binding> bindingsMap = rascalToJavaBindings(bindings);
			
			getEngine.get().delete(query, bindingsMap);
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}

	@Override
	public void close() throws Exception {
		// TODO Auto-generated method stub
		
	}

}
