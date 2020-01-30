package nl.cwi.swat.typhonql.backend.rascal;


import java.util.Collections;
import java.util.Map;
import java.util.function.Function;

import org.rascalmpl.interpreter.IEvaluatorContext;
import org.rascalmpl.interpreter.control_exceptions.MatchFailed;
import org.rascalmpl.interpreter.env.Environment;
import org.rascalmpl.interpreter.result.AbstractFunction;
import org.rascalmpl.interpreter.result.ICallableValue;
import org.rascalmpl.interpreter.result.Result;
import org.rascalmpl.interpreter.types.FunctionType;

import io.usethesource.vallang.IValue;
import io.usethesource.vallang.type.Type;

public interface Operations {
	// no support for kw params yet 
	default ICallableValue makeFunction(IEvaluatorContext ctx, FunctionType typ, Function<IValue[], Result<IValue>> body) {
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
