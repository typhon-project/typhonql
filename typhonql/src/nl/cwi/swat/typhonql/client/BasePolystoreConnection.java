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
import org.rascalmpl.interpreter.utils.RascalManifest;
import org.rascalmpl.library.util.PathConfig;
import org.rascalmpl.uri.URIResolverRegistry;
import org.rascalmpl.uri.URIUtil;
import org.rascalmpl.uri.classloaders.SourceLocationClassLoader;
import org.rascalmpl.util.ConcurrentSoftReferenceObjectPool;
import org.rascalmpl.values.ValueFactoryFactory;

import io.usethesource.vallang.IInteger;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IMapWriter;
import io.usethesource.vallang.ISourceLocation;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import nl.cwi.swat.typhonql.ConnectionInfo;
import nl.cwi.swat.typhonql.Connections;

/**
 * Thread safe connection to the polystore ql engine, construct this once, and call the executeQuery from as many threads as you like (there is a memory overhead, but it will not interfer with eachother)
 */
public abstract class BasePolystoreConnection extends PolystoreConnection {

	protected final ConcurrentSoftReferenceObjectPool<Evaluator> evaluators;
	protected IMap connections;
	protected static final IValueFactory VF = ValueFactoryFactory.getValueFactory();
	protected static final String LOCALHOST = "localhost";
	
	private static int calculateMaxEvaluators() {
        int numberOfEvaluators = Math.min(4, Runtime.getRuntime().availableProcessors() - 2);
        if (numberOfEvaluators > 1) {
            numberOfEvaluators = Math.min(numberOfEvaluators, (int)(Runtime.getRuntime().maxMemory()/ (1024*1024*300L))); // give at least 300MB per evaluator.
        }
        return Math.max(1, numberOfEvaluators);
	}

	
	private static boolean hasRascalMF(ISourceLocation root) {
		return URIResolverRegistry.getInstance().exists(URIUtil.getChildLocation(root, RascalManifest.META_INF_RASCAL_MF));
	}

	public BasePolystoreConnection(List<DatabaseInfo> infos) throws IOException {
		// bootstrap the connections
				Connections.boot(infos.stream().map(i -> new ConnectionInfo(LOCALHOST, i)).toArray(ConnectionInfo[]::new));

				// we prepare some configuration that every evaluator will need
				connections = buildConnectionsMap(infos);

				ISourceLocation root = URIUtil.correctLocation("project", "typhonql", null);
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
		                root = URIUtil.createFileLocation(BasePolystoreConnection.class.getProtectionDomain().getCodeSource().getLocation().getPath());
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
				ClassLoader cl = new SourceLocationClassLoader(pcfg.getClassloaders(), BasePolystoreConnection.class.getClassLoader());
				
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
					result.doImport(null, "lang::typhonql::RunUsingCompiler");
					result.doImport(null, "lang::typhonql::Run");
					System.out.println("Finished initializing evaluator: " + Integer.toHexString(System.identityHashCode(result)));
					System.out.flush();
					return result;
				});
	}


	private IMap buildConnectionsMap(List<DatabaseInfo> infos) {
		IMapWriter mw = VF.mapWriter();
		for (DatabaseInfo info : infos) {
			IString host = VF.string(info.getHost());
			IInteger port = VF.integer(info.getPort());
			IString user = VF.string(info.getUser());
			IString password = VF.string(info.getPassword());
			IString dbName = VF.string(info.getDbName());
			switch (info.getDbType()) { 
			case relationaldb:
				mw.put(dbName, VF.tuple(VF.string("sql"), host, port, user, password));
				break;
			case documentdb:
				mw.put(dbName,  VF.tuple(VF.string("mongo"), host, port, user, password));
				break;
			}
		}
		
		return mw.done();
	}
}
