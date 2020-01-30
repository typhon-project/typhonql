package nl.cwi.swat.typhonql.backend.rascal;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Objects;

import org.rascalmpl.interpreter.IEvaluatorContext;
import org.rascalmpl.interpreter.env.ModuleEnvironment;
import org.rascalmpl.interpreter.result.ICallableValue;
import org.rascalmpl.interpreter.result.ResultFactory;
import org.rascalmpl.interpreter.types.FunctionType;

import io.usethesource.vallang.ISet;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeFactory;
import io.usethesource.vallang.type.TypeStore;
import nl.cwi.swat.typhonql.backend.EntityModel;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.workingset.WorkingSet;
import nl.cwi.swat.typhonql.workingset.json.WorkingSetJSON;

public class TyphonSession implements Operations {
	private static final TypeFactory TF = TypeFactory.getInstance();
	private final IValueFactory vf;
	
	public TyphonSession(IValueFactory vf) {
		this.vf = vf;
	}
	
	public TyphonSession(IValueFactory vf) {
		this.vf = vf;
	}

	public ITuple newSession(IEvaluatorContext ctx) {
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
		FunctionType readType = (FunctionType)aliasedTuple.getFieldType("read");
		FunctionType closeType = (FunctionType)aliasedTuple.getFieldType("done");

		// construct the session tuple
		ResultStore store = new ResultStore();
		return vf.tuple(
			makeRead(store, readType, ctx),
            makeClose(store, closeType, ctx),
            new MariaDBOperations().newSQLOperations(store, ctx, vf, TF),
            new MongoOperations().newMongoOperations(store, ctx, vf, TF)
		);
	}
	

	private ICallableValue makeClose(ResultStore store, FunctionType closeType, IEvaluatorContext ctx) {
		return makeFunction(ctx, closeType, args -> {
			store.clear();
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}

	private ICallableValue makeRead(ResultStore store, FunctionType readType, IEvaluatorContext ctx) {
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

}
