package engineering.swat.typhonql.ast;

import java.lang.reflect.Constructor;
import java.lang.reflect.InvocationTargetException;
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;
import java.util.stream.Collectors;
import org.rascalmpl.interpreter.AssignableEvaluator;
import org.rascalmpl.interpreter.IEvaluator;
import org.rascalmpl.interpreter.IEvaluatorContext;
import org.rascalmpl.interpreter.asserts.ImplementationError;
import org.rascalmpl.interpreter.asserts.NotYetImplemented;
import org.rascalmpl.interpreter.control_exceptions.Throw;
import org.rascalmpl.interpreter.env.Environment;
import org.rascalmpl.interpreter.matching.IBooleanResult;
import org.rascalmpl.interpreter.matching.IMatchingResult;
import org.rascalmpl.interpreter.result.Result;
import org.rascalmpl.interpreter.result.ResultFactory;
import org.rascalmpl.interpreter.staticErrors.UnsupportedPattern;
import org.rascalmpl.interpreter.types.RascalTypeFactory;
import org.rascalmpl.values.uptr.IRascalValueFactory;
import io.usethesource.vallang.IBool;
import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.ISourceLocation;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeFactory;

public abstract class AbstractAST {
	protected static final TypeFactory TF = TypeFactory.getInstance();
	protected static final RascalTypeFactory RTF = RascalTypeFactory.getInstance();
	protected static final IRascalValueFactory VF = IRascalValueFactory.getInstance();
	protected ISourceLocation src;
	
	AbstractAST(ISourceLocation src) {
		this.src = src;
	}
	
	
	/**
	 * Used in clone and AST Builder
	 */
	@SuppressWarnings("unchecked")
	public static <T extends AbstractAST> T newInstance(java.lang.Class<T> clazz, Object... args) {
    	try {
    		Constructor<?> cons = clazz.getConstructors()[0];
    		cons.setAccessible(true);
    		return (T) cons.newInstance(args);
    	}
    	catch (ClassCastException | ArrayIndexOutOfBoundsException | SecurityException | InstantiationException | IllegalAccessException | IllegalArgumentException | InvocationTargetException e) {
    		throw new ImplementationError("Can not instantiate AST object for " + clazz.getName(), e);
    	}
    }
	
	public AbstractAST findNode(int offset) {
		if (src.getOffset() <= offset
				&& offset < src.getOffset() + src.getLength()) {
			return this;
		}
		
		return null;
	}
	

	public <T> T accept(IASTVisitor<T> v) {
		return null;
	}

	public ISourceLocation getLocation() {
		return src;
	}

	@Override
	public boolean equals(Object obj) {
		throw new ImplementationError("Missing generated hashCode/equals methods");
	}

	@Override
	public int hashCode() {
		throw new ImplementationError("Missing generated concrete hashCode/equals methods");
	}

	@Override
	@Deprecated
	/**
	 * @deprecated YOU SHOULD NOT USE THIS METHOD for user information. Use {@link Names}.
	 */
	public String toString() {
		return "AST debug info: " + getClass().getName() + " at " + src;
	}
}
