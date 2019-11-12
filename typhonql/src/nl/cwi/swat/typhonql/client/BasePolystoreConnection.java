package nl.cwi.swat.typhonql.client;

import java.io.IOException;
import java.io.PrintWriter;
import java.net.URISyntaxException;
import java.util.List;
import java.util.concurrent.TimeUnit;

import org.rascalmpl.interpreter.Evaluator;
import org.rascalmpl.interpreter.env.GlobalEnvironment;
import org.rascalmpl.interpreter.env.ModuleEnvironment;
import org.rascalmpl.interpreter.load.StandardLibraryContributor;
import org.rascalmpl.library.util.PathConfig;
import org.rascalmpl.uri.URIResolverRegistry;
import org.rascalmpl.uri.URIUtil;
import org.rascalmpl.uri.classloaders.SourceLocationClassLoader;
import org.rascalmpl.util.ConcurrentSoftReferenceObjectPool;
import org.rascalmpl.values.ValueFactoryFactory;

import io.usethesource.vallang.ISourceLocation;
import io.usethesource.vallang.IValue;
import nl.cwi.swat.typhonql.ConnectionInfo;
import nl.cwi.swat.typhonql.Connections;

/**
 * Thread safe connection to the polystore ql engine, construct this once, and call the executeQuery from as many threads as you like (there is a memory overhead, but it will not interfer with eachother)
 */
public abstract class BasePolystoreConnection extends PolystoreConnection {
	
	protected static final String LOCALHOST = "localhost";
	protected final ConcurrentSoftReferenceObjectPool<Evaluator> evaluators;
	
	private static int calculateMaxEvaluators() {
        int numberOfEvaluators = Math.min(4, Runtime.getRuntime().availableProcessors() - 2);
        if (numberOfEvaluators > 1) {
            numberOfEvaluators = Math.min(numberOfEvaluators, (int)(Runtime.getRuntime().maxMemory()/ (1024*1024*300L))); // give at least 300MB per evaluator.
        }
        return Math.max(1, numberOfEvaluators);
	}


	public BasePolystoreConnection(List<DatabaseInfo> infos) throws IOException {
		// bootstrap the connections
				Connections.boot(infos.stream().map(i -> new ConnectionInfo(LOCALHOST, i)).toArray(ConnectionInfo[]::new));

				// we prepare some configuration that every evaluator will need
				

				URIResolverRegistry reg = URIResolverRegistry.getInstance();
				if (!reg.getRegisteredInputSchemes().contains("project") && !reg.getRegisteredLogicalSchemes().contains("project")) {
					// project URI is not supported, so we have to add support for this (we have to do this only once)
		            ISourceLocation projectRoot;
		            try {
		                projectRoot = URIUtil.createFileLocation(SimplePolystoreConnection.class.getProtectionDomain().getCodeSource().getLocation().getPath());
		                if (projectRoot.getPath().endsWith(".jar")) {
		                    projectRoot = URIUtil.changePath(URIUtil.changeScheme(projectRoot, "jar+" + projectRoot.getScheme()), projectRoot.getPath() + "!/");
		                }
		            } catch (URISyntaxException e) {
		                throw new RuntimeException("Cannot get to root of the typhonql project", e);
		            }
					//reg.registerLogical(new ProjectURIResolver(projectRoot, "typhonql"));
					// from now on, |project://typhonql/| should work
				}

				PathConfig pcfg = PathConfig.fromSourceProjectRascalManifest(URIUtil.correctLocation("lib", "typhonql", null));
				ClassLoader cl = new SourceLocationClassLoader(pcfg.getClassloaders(), SimplePolystoreConnection.class.getClassLoader());
				
				evaluators = new ConcurrentSoftReferenceObjectPool<>(10, TimeUnit.MINUTES, 1, calculateMaxEvaluators(), () -> {
					// we construct a new evaluator for every concurrent call
					GlobalEnvironment  heap = new GlobalEnvironment();
					Evaluator result = new Evaluator(ValueFactoryFactory.getValueFactory(), 
							new PrintWriter(System.err, true), new PrintWriter(System.out, false),
							new ModuleEnvironment("$typhonql$", heap), heap);
					
					result.addRascalSearchPathContributor(StandardLibraryContributor.getInstance());
					result.addRascalSearchPath(pcfg.getBin());
					for (IValue path : pcfg.getSrcs()) {
						result.addRascalSearchPath((ISourceLocation) path); 
					}
					result.addClassLoader(cl);

					System.out.println("Starting a fresh evaluator to interpret the query (" + Integer.toHexString(System.identityHashCode(result)) + ")");
					System.out.flush();
					// now we are ready to import our main module
					result.doImport(null, "lang::typhonql::Run");
					System.out.println("Finished initializing evaluator: " + Integer.toHexString(System.identityHashCode(result)));
					System.out.flush();
					return result;
				});
	}

}