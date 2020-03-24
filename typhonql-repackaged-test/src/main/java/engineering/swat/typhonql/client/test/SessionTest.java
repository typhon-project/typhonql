package engineering.swat.typhonql.client.test;

import java.io.IOException;
import java.io.PrintWriter;
import java.net.URISyntaxException;
import java.util.Collections;

import org.rascalmpl.interpreter.Evaluator;
import org.rascalmpl.interpreter.env.GlobalEnvironment;
import org.rascalmpl.interpreter.env.ModuleEnvironment;
import org.rascalmpl.interpreter.load.StandardLibraryContributor;
import org.rascalmpl.interpreter.utils.RascalManifest;
import org.rascalmpl.library.util.PathConfig;
import org.rascalmpl.uri.URIResolverRegistry;
import org.rascalmpl.uri.URIUtil;
import org.rascalmpl.uri.classloaders.SourceLocationClassLoader;
import org.rascalmpl.values.ValueFactoryFactory;

import io.usethesource.vallang.ISourceLocation;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import nl.cwi.swat.typhonql.client.PolystoreConnection;

public class SessionTest {
	
	private static boolean hasRascalMF(ISourceLocation root) {
		return URIResolverRegistry.getInstance().exists(URIUtil.getChildLocation(root, RascalManifest.META_INF_RASCAL_MF));
	}


	public static void main(String[] args) throws IOException {
		IValueFactory vf = ValueFactoryFactory.getValueFactory();
		ISourceLocation root = URIUtil.correctLocation("project", "typhonql", null);
		GlobalEnvironment heap = new GlobalEnvironment();
		URIResolverRegistry reg = URIResolverRegistry.getInstance();
		if (!hasRascalMF(root)) {
			// project not available, switch to lib
			root = URIUtil.correctLocation("lib", "typhonql", null);
		}
		if (!hasRascalMF(root)) {
			// maybe lib scheme does not exist yet, so we switch to the plugin scheme
			root = URIUtil.correctLocation("plugin", "typhonql", null);
		}
		if (!hasRascalMF(root)) {
			// we are not inside eclipse/OSGI, so we are in the headless version, so we have to help the registry in finding 
            try {
                root = URIUtil.createFileLocation(PolystoreConnection.class.getProtectionDomain().getCodeSource().getLocation().getPath());
                if (root.getPath().endsWith(".jar")) {
                    root = URIUtil.changePath(URIUtil.changeScheme(root, "jar+" + root.getScheme()), root.getPath() + "!/");
                }
            } catch (URISyntaxException e) {
                throw new RuntimeException("Cannot get to root of the typhonql project", e);
            }
		}
		if (!hasRascalMF(root)) {
			if (root.getScheme().equals("file") && root.getPath().endsWith("/target/classes/")) {
				// last resort, we are in a 1st level eclipse on the typhonql project itself, now RASCAL.MF file is harder to find
				try {
					root = URIUtil.changePath(root, root.getPath().replace("/target/classes/", ""));
				} catch (URISyntaxException e) {
					throw new RuntimeException("Cannot get to root of the typhonql project", e);
				}
			}
		}

		if (!hasRascalMF(root)) {
			System.err.println("Running polystore jar in a strange context, cannot find rascal.mf file & and related modules");
			System.err.println("Last location tried: " + root);
		}

		
		PathConfig pcfg = PathConfig.fromSourceProjectRascalManifest(root);
		ClassLoader cl = new SourceLocationClassLoader(pcfg.getClassloaders(), SessionTest.class.getClassLoader());
		
		

		Evaluator result = new Evaluator(ValueFactoryFactory.getValueFactory(), new PrintWriter(System.err, true),
				new PrintWriter(System.out, false), new ModuleEnvironment("$typhonql$", heap), heap);

		result.addRascalSearchPathContributor(StandardLibraryContributor.getInstance());
		result.addRascalSearchPath(pcfg.getBin());
		for (IValue path : pcfg.getSrcs()) {
			result.addRascalSearchPath((ISourceLocation) path);
		}
		result.addClassLoader(cl);

		System.out.println("Starting a fresh evaluator to interpret the query ("
				+ Integer.toHexString(System.identityHashCode(result)) + ")");
		System.out.flush();
		// now we are ready to import our main module
		result.doImport(null, "lang::typhonql::test::TestsCompiler");
		//result.doImport(null, "lang::typhonql::TestScript");
		//result.call("smokeTwoBackends2", "lang::typhonql::TestScript", Collections.<String, IValue>emptyMap());
		result.call("test8b", "lang::typhonql::test::TestsCompiler", Collections.<String, IValue>emptyMap());
	}

}
