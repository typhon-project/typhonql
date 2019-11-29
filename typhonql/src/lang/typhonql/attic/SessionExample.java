package lang.typhonql.attic;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;
import java.util.function.Function;
import org.rascalmpl.ast.KeywordFormal;
import org.rascalmpl.debug.IRascalMonitor;
import org.rascalmpl.interpreter.IEvaluator;
import org.rascalmpl.interpreter.IEvaluatorContext;
import org.rascalmpl.interpreter.control_exceptions.MatchFailed;
import org.rascalmpl.interpreter.env.Environment;
import org.rascalmpl.interpreter.env.ModuleEnvironment;
import org.rascalmpl.interpreter.result.AbstractFunction;
import org.rascalmpl.interpreter.result.ICallableValue;
import org.rascalmpl.interpreter.result.Result;
import org.rascalmpl.interpreter.result.ResultFactory;
import org.rascalmpl.interpreter.types.FunctionType;
import com.mysql.cj.exceptions.ExceptionFactory;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeFactory;
import io.usethesource.vallang.type.TypeStore;

public class SessionExample {
	private static final TypeFactory TF = TypeFactory.getInstance();
	private final IValueFactory vf;

	public SessionExample(IValueFactory vf) {
		this.vf = vf;
	}

	public ITuple newSession(IEvaluatorContext ctx) {
		// borrow the type store from the module, so we don't have to build the function type ourself
        ModuleEnvironment aliasModule = ctx.getHeap().getModule("lang::typhonql::attic::SessionExample");
        if (aliasModule == null) {
        	throw new IllegalArgumentException("Missing my own module");
        }
        TypeStore ts = aliasModule.getStore();
		Type aliasedTuple = Objects.requireNonNull(ctx.getCurrentEnvt().lookupAlias("Session"));
		while (aliasedTuple.isAliased()) {
			aliasedTuple = aliasedTuple.getAliased();
		}


		// get the function types
		FunctionType executeType = (FunctionType)aliasedTuple.getFieldType("execute");
		FunctionType readType = (FunctionType)aliasedTuple.getFieldType("read");
		FunctionType closeType = (FunctionType)aliasedTuple.getFieldType("close");

		// construct the session tuple
		Map<IString, IString> sessionData = new HashMap<>();
		return vf.tuple(
            makeExecute(sessionData, executeType, ctx),
            makeRead(sessionData, readType, ctx),
            makeClose(sessionData, closeType, ctx)
		);
	}
	

	private ICallableValue makeClose(Map<IString, IString> sessionData, FunctionType closeType, IEvaluatorContext ctx) {
		return makeFunction(ctx, closeType, args -> {
			sessionData.clear();
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}

	private ICallableValue makeRead(Map<IString, IString> sessionData, FunctionType readType, IEvaluatorContext ctx) {
		return makeFunction(ctx, readType, args -> {
			IString result = sessionData.get(args[0]);
			if (result == null) {
				result = vf.string("Not available");
			}
			return ResultFactory.makeResult(TF.stringType(), result, ctx);
		});
	}

	private ICallableValue makeExecute(Map<IString, IString> sessionData, FunctionType executeType, IEvaluatorContext ctx) {
		return makeFunction(ctx, executeType, args -> {
			IString resultName = (IString) args[0];
			IString query = (IString) args[1];
			sessionData.put(resultName, query);
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
