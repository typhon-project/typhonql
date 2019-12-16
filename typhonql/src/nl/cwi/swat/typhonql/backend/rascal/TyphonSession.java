package nl.cwi.swat.typhonql.backend.rascal;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Objects;
import java.util.function.Function;

import org.rascalmpl.interpreter.Evaluator;
import org.rascalmpl.interpreter.IEvaluatorContext;
import org.rascalmpl.interpreter.control_exceptions.MatchFailed;
import org.rascalmpl.interpreter.env.Environment;
import org.rascalmpl.interpreter.env.GlobalEnvironment;
import org.rascalmpl.interpreter.env.ModuleEnvironment;
import org.rascalmpl.interpreter.load.StandardLibraryContributor;
import org.rascalmpl.interpreter.result.AbstractFunction;
import org.rascalmpl.interpreter.result.ICallableValue;
import org.rascalmpl.interpreter.result.Result;
import org.rascalmpl.interpreter.result.ResultFactory;
import org.rascalmpl.interpreter.types.FunctionType;
import org.rascalmpl.library.util.PathConfig;
import org.rascalmpl.uri.URIUtil;
import org.rascalmpl.uri.classloaders.SourceLocationClassLoader;
import org.rascalmpl.values.ValueFactoryFactory;

import io.usethesource.vallang.IInteger;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.ISet;
import io.usethesource.vallang.ISourceLocation;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeFactory;
import io.usethesource.vallang.type.TypeStore;
import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.Engine;
import nl.cwi.swat.typhonql.backend.EntityModel;
import nl.cwi.swat.typhonql.backend.MariaDBEngineFactory;
import nl.cwi.swat.typhonql.backend.MongoDBEngineFactory;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.client.SimplePolystoreConnection;
import nl.cwi.swat.typhonql.workingset.WorkingSet;
import nl.cwi.swat.typhonql.workingset.json.WorkingSetJSON;

public class TyphonSession {
	private static final TypeFactory TF = TypeFactory.getInstance();
	private final IValueFactory vf;
	
	public TyphonSession(IValueFactory vf) {
		this.vf = vf;
		BackendRegistry.addEngineFactory("MariaDB", new MariaDBEngineFactory());
		BackendRegistry.addEngineFactory("MongoDB", new MongoDBEngineFactory());
	}

	public ITuple newSession(ISet databases, IEvaluatorContext ctx) {
		// borrow the type store from the module, so we don't have to build the function type ourself
        ModuleEnvironment aliasModule = ctx.getHeap().getModule("lang::typhonql::Session");
        if (aliasModule == null) {
        	throw new IllegalArgumentException("Missing my own module");
        }
        TypeStore ts = aliasModule.getStore();
		Type aliasedTuple = Objects.requireNonNull(ctx.getCurrentEnvt().lookupAlias("Session"));
		while (aliasedTuple.isAliased()) {
			aliasedTuple = aliasedTuple.getAliased();
		}


		// get the function types
		FunctionType executeType = (FunctionType)aliasedTuple.getFieldType("executeQuery");
		FunctionType readType = (FunctionType)aliasedTuple.getFieldType("read");
		FunctionType closeType = (FunctionType)aliasedTuple.getFieldType("done");

		// construct the session tuple
		ResultStore store = new ResultStore();
		
		Map<String, Engine> dbs = new HashMap<String, Engine>();
		
		Iterator<IValue> iter = databases.iterator();
		while (iter.hasNext()) {
			ITuple tuple = (ITuple) iter.next();
			IString dbName = (IString) tuple.get(0);
			IString dbType = (IString) tuple.get(1);
			IString host = (IString) tuple.get(2);
			IInteger port = (IInteger) tuple.get(3);
			IString user = (IString) tuple.get(4);
			IString password = (IString) tuple.get(5);
			Engine engine = BackendRegistry.createEngine(dbType.getValue(), store, host.getValue(), 
					port.intValue(), dbName.getValue(), user.getValue(), password.getValue());
			dbs.put(dbName.getValue(), engine);
		}
		
		return vf.tuple(
            makeExecuteQuery(store, dbs, executeType, ctx),
            makeRead(store, dbs, readType, ctx),
            makeClose(store, dbs, closeType, ctx)
		);
	}
	

	private ICallableValue makeClose(ResultStore store, Map<String, Engine> dbs, FunctionType closeType, IEvaluatorContext ctx) {
		return makeFunction(ctx, closeType, args -> {
			store.clear();
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}

	private ICallableValue makeRead(ResultStore store, Map<String, Engine> dbs,  FunctionType readType, IEvaluatorContext ctx) {
		return makeFunction(ctx, readType, args -> {
			String resultName = ((IString) args[0]).getValue();
			List<String> labels = new ArrayList<>();
			List<String> types = new ArrayList<>();
			
			ISet nameTypeRel = (ISet) args[1];
			ISet modelsRel = (ISet) args[2];
			Iterator<IValue> iter = nameTypeRel.iterator();
			
			while (iter.hasNext()) {
				ITuple tuple = (ITuple) iter.next();
				IString name = (IString) tuple.get(0);
				IString type = (IString) tuple.get(1);
				labels.add(name.getValue());
				types.add(type.getValue());
			}
			
			List<EntityModel> models = EntityModelReader.fromRascalRelation(types, modelsRel);
			
			WorkingSet ws = store.computeResult(resultName, labels.toArray(new String[0]), models.toArray(new EntityModel[0]));
			
 			ByteArrayOutputStream os = new ByteArrayOutputStream();
 			
 			try {
				WorkingSetJSON.toJSON(ws, os);
				os.flush();
			} catch (IOException e) {
				throw new RuntimeException(e);
			}
 			
 			String json = new String(os.toByteArray());
 			return ResultFactory.makeResult(TF.stringType(), vf.string(json), ctx);
		});
	}

	private ICallableValue makeExecuteQuery(ResultStore store, Map<String, Engine> dbs, FunctionType executeType, IEvaluatorContext ctx) {
		return makeFunction(ctx, executeType, args -> {
			IString resultId = (IString) args[0];
			IString dbName = (IString) args[1];
			IString query = (IString) args[2];
			IMap bindings =  (IMap) args[3];
			
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
			
			dbs.get(dbName.getValue()).executeSelect(resultId.getValue(), query.getValue(), bindingsMap);
			
			//sessionData.put(resultName, query);
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}
	
	// no support for kw params yet 
	private ICallableValue makeFunction(IEvaluatorContext ctx, FunctionType typ, Function<IValue[], Result<IValue>> body) {
		return new AbstractFunction(ctx.getCurrentAST(), ctx.getEvaluator(), typ, Collections.emptyList(), false, ctx.getCurrentEnvt()) {
			
			@Override
			public boolean isStatic() {
				return false;
			}
			
			@Override
			public ICallableValue cloneInto(Environment env) {
				// should not happen, we are not part of an environment
				return null;
			}
			
			@Override
			public boolean isDefault() {
				return false;
			}
			
			@Override
			public Result<IValue> call(Type[] argTypes, IValue[] argValues, Map<String, IValue> keyArgValues) throws MatchFailed {
				return body.apply(argValues);
			}
		};
		
	}



}
