package nl.cwi.swat.typhonql.backend.rascal;

import java.io.File;
import java.lang.reflect.Constructor;
import java.lang.reflect.InvocationTargetException;
import java.net.URL;
import java.net.URLClassLoader;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Consumer;

import javax.tools.Diagnostic;
import javax.tools.JavaFileObject;

import org.rascalmpl.interpreter.utils.JavaCompiler;
import org.rascalmpl.interpreter.utils.JavaCompilerException;

import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.Runner;

public class JavaOperation  {

	
	public static void compileAndAggregate(ResultStore store, TyphonSessionState state,
			List<Consumer<List<Record>>> script, Map<String, UUID> uuids, String className,
			String classBody, List<Path> paths, List<String> columnNames) {
		List<String> commandLine = new ArrayList<>();
		commandLine.add("-proc:none");
		commandLine.add("-cp");
		String cpFull = System.getProperty("java.class.path");
		ClassLoader cl = JavaOperation.class.getClassLoader();
		if (cl instanceof URLClassLoader) {
			for (URL u: ((URLClassLoader)cl).getURLs()) {
				try {
					cpFull += (cpFull.isEmpty() ? "" : System.getProperty("path.separator")) + new File(u.getFile()).getAbsolutePath();
				} catch (Exception e) {
				}
			}
		}
		commandLine.add(cpFull);
		
		JavaCompiler<JavaOperationImplementation> javaCompiler = new JavaCompiler<JavaOperationImplementation>(JavaOperation.class.getClassLoader(), null, commandLine);
		try {
			Class<JavaOperationImplementation> result = javaCompiler.compile(className, classBody, null, JavaOperationImplementation.class);
			Constructor<JavaOperationImplementation> ctr = result.getConstructor(ResultStore.class, TyphonSessionState.class, Map.class);
			JavaOperationImplementation op = ctr.newInstance(store, state, uuids);
			state.setResult(Runner.computeResultStream(script, paths, columnNames, op::processStream));
		} catch (ClassCastException | InstantiationException | IllegalAccessException | IllegalArgumentException | InvocationTargetException | NoSuchMethodException | SecurityException e) {
			throw new RuntimeException(e);
		} catch (JavaCompilerException e) {
		    if (!e.getDiagnostics().getDiagnostics().isEmpty()) {
		        Diagnostic<? extends JavaFileObject> msg = e.getDiagnostics().getDiagnostics().iterator().next();
		        throw new RuntimeException(msg.getMessage(null) + " at " + msg.getLineNumber() + ", " + msg.getColumnNumber(), e);
		    }
			throw new RuntimeException(e);
		}
	}


}
