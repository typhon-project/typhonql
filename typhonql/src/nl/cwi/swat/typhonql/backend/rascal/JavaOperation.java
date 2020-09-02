package nl.cwi.swat.typhonql.backend.rascal;

import java.lang.reflect.Constructor;
import java.lang.reflect.InvocationTargetException;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Consumer;

import org.rascalmpl.interpreter.utils.JavaCompiler;
import org.rascalmpl.interpreter.utils.JavaCompilerException;

import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.Runner;

public class JavaOperation  {

	public static void compileAndAggregate(ResultStore store, TyphonSessionState state,
			List<Consumer<List<Record>>> script, List<Runnable> updates, Map<String, UUID> uuids, String className,
			String classBody, List<Path> paths, List<String> columnNames) {
		List<String> commandline = Arrays.asList(new String[] {"-proc:none", "-cp", System.getProperty("java.class.path")});
		JavaCompiler<JavaOperationImplementation> javaCompiler = new JavaCompiler<JavaOperationImplementation>(JavaOperation.class.getClassLoader(), null, commandline);
		try {
			Class<JavaOperationImplementation> result = javaCompiler.compile(className, classBody, null, JavaOperationImplementation.class);
			Constructor<JavaOperationImplementation> ctr = result.getConstructor(ResultStore.class, TyphonSessionState.class, Map.class);
			JavaOperationImplementation op = ctr.newInstance(store, state, uuids);
			state.setResult(Runner.computeResultStream(script, paths, columnNames, op::processStream));
		} catch (ClassCastException | JavaCompilerException | InstantiationException | IllegalAccessException | IllegalArgumentException | InvocationTargetException | NoSuchMethodException | SecurityException e) {
			throw new RuntimeException(e);
		}
	}


}
