package nl.cwi.swat.typhonql.client;

import static org.rascalmpl.interpreter.utils.ReadEvalPrintDialogMessages.staticErrorMessage;
import static org.rascalmpl.interpreter.utils.ReadEvalPrintDialogMessages.throwMessage;
import static org.rascalmpl.interpreter.utils.ReadEvalPrintDialogMessages.throwableMessage;

import java.io.IOException;
import java.io.PrintWriter;
import java.net.URI;
import java.net.URISyntaxException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Iterator;
import java.util.List;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;

import org.rascalmpl.interpreter.Evaluator;
import org.rascalmpl.interpreter.control_exceptions.Throw;
import org.rascalmpl.interpreter.env.GlobalEnvironment;
import org.rascalmpl.interpreter.env.ModuleEnvironment;
import org.rascalmpl.interpreter.load.StandardLibraryContributor;
import org.rascalmpl.interpreter.staticErrors.StaticError;
import org.rascalmpl.interpreter.utils.RascalManifest;
import org.rascalmpl.library.util.PathConfig;
import org.rascalmpl.uri.URIResolverRegistry;
import org.rascalmpl.uri.URIUtil;
import org.rascalmpl.uri.classloaders.SourceLocationClassLoader;
import org.rascalmpl.util.ConcurrentSoftReferenceObjectPool;
import org.rascalmpl.values.ValueFactoryFactory;

import io.usethesource.vallang.IInteger;
import io.usethesource.vallang.IList;
import io.usethesource.vallang.IListWriter;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IMapWriter;
import io.usethesource.vallang.ISourceLocation;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.io.StandardTextWriter;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeFactory;
import io.usethesource.vallang.type.TypeStore;
import nl.cwi.swat.typhonql.DBType;
import nl.cwi.swat.typhonql.MariaDB;
import nl.cwi.swat.typhonql.MongoDB;
import nl.cwi.swat.typhonql.backend.rascal.TyphonSession;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;
import nl.cwi.swat.typhonql.workingset.Entity;

public class XMIPolystoreConnection implements PolystoreConnection {
	private static final StandardTextWriter VALUE_PRINTER = new StandardTextWriter(true, 2);

	private volatile IString xmiModel;
	private final ConcurrentSoftReferenceObjectPool<Evaluator> evaluators;
	private static final IValueFactory VF = ValueFactoryFactory.getValueFactory();
	private static final TypeFactory TF = TypeFactory.getInstance();
	private IMap connections;

	private TyphonSession sessionBuilder;
	
	public XMIPolystoreConnection(String xmiModel, List<DatabaseInfo> infos) throws IOException {
		this(infos);
		this.xmiModel = VF.string(xmiModel);
		this.sessionBuilder = new TyphonSession(VF);
	}
	
	private XMIPolystoreConnection(List<DatabaseInfo> infos) throws IOException {
				this.connections = buildConnections(infos);
				ISourceLocation root = URIUtil.correctLocation("project", "typhonql", null);
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
		                root = URIUtil.createFileLocation(XMIPolystoreConnection.class.getProtectionDomain().getCodeSource().getLocation().getPath());
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
				ClassLoader cl = new SourceLocationClassLoader(pcfg.getClassloaders(), XMIPolystoreConnection.class.getClassLoader());
				
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
					result.doImport(null, "lang::typhonql::Session");
					System.out.println("Finished initializing evaluator: " + Integer.toHexString(System.identityHashCode(result)));
					System.out.flush();
					return result;
				});
	}
	
	public void setXmiModel(String xmiModel) {
		this.xmiModel = VF.string(xmiModel);
	}
	
	@Override
	public ResultTable executeQuery(String query) {
		return evaluators.useAndReturn(evaluator -> {
			try {
				synchronized (evaluator) {
					ITuple session = sessionBuilder.newSession(connections, evaluator);
					// str src, str xmiString, Session session
					IValue v = evaluator.call("runQueryAndGetJava", 
							"lang::typhonql::RunUsingCompiler",
                    		Collections.emptyMap(),
							VF.string(query), 
							xmiModel,
							session);
					return (ResultTable) v;
				}
			} catch (StaticError e) {
				staticErrorMessage(evaluator.getStdErr(), e, VALUE_PRINTER);
				throw e;
			} catch (Throw e) {
				throwMessage(evaluator.getStdErr(), e, VALUE_PRINTER);
				throw e;
			} catch (Throwable e) {
				throwableMessage(evaluator.getStdErr(), e, evaluator.getStackTrace(), VALUE_PRINTER);
				throw e;
			}
		});
	}
	
	@Override
	public void executeDDLUpdate(String update) {
		evaluators.useAndReturn(evaluator -> {
			try {
				synchronized (evaluator) {
					// str src, str xmiString, Session sessions
					return evaluator.call("runDDL", 
							"lang::typhonql::RunUsingCompiler",
                    		Collections.emptyMap(),
							VF.string(update), 
							xmiModel,
							connections);
				}
			} catch (StaticError e) {
				staticErrorMessage(evaluator.getStdErr(), e, VALUE_PRINTER);
				throw e;
			} catch (Throw e) {
				throwMessage(evaluator.getStdErr(), e, VALUE_PRINTER);
				throw e;
			} catch (Throwable e) {
				throwableMessage(evaluator.getStdErr(), e, evaluator.getStackTrace(), VALUE_PRINTER);
				throw e;
			}
		});
		
	}
	
	public CommandResult executeUpdate(String query) {
		IValue val = evaluateUpdate(query);
		return CommandResult.fromIValue(val);
	}
	
	
	private IValue evaluateUpdate(String update) {
		return evaluators.useAndReturn(evaluator -> {
			try {
				synchronized (evaluator) {
					// str src, str xmiString, Session sessions
					ITuple session = createSession(evaluator);
					return evaluator.call("runUpdate", 
							"lang::typhonql::RunUsingCompiler",
                    		Collections.emptyMap(),
							VF.string(update), 
							xmiModel,
							session);
				}
			} catch (StaticError e) {
				staticErrorMessage(evaluator.getStdErr(), e, VALUE_PRINTER);
				throw e;
			} catch (Throw e) {
				throwMessage(evaluator.getStdErr(), e, VALUE_PRINTER);
				throw e;
			} catch (Throwable e) {
				throwableMessage(evaluator.getStdErr(), e, evaluator.getStackTrace(), VALUE_PRINTER);
				throw e;
			}
		});
	}
	

	private IValue evaluatePreparedStatementQuery(String preparedStatement, String[] columnNames, String[][] matrix) {
		IListWriter lw = VF.listWriter();
		for (Object[] row : matrix) {
			List<IValue> vs = Arrays.asList(row).stream().map(
					obj -> Entity.toIValue(VF, obj)).collect(Collectors.toList());
			IListWriter lw1 = VF.listWriter();
			lw1.appendAll(vs);
			lw.append(lw1.done());
		}
		IListWriter columnsWriter = VF.listWriter();
		columnsWriter.appendAll(Arrays.asList(columnNames).stream().map(columnName -> VF.string(columnName)).collect(Collectors.toList()));
		return evaluators.useAndReturn(evaluator -> {
			try {
				synchronized (evaluator) {
					ITuple session = createSession(evaluator);
					// str src, str polystoreId, Schema s, Session session
					return evaluator.call("runPrepared", 
							"lang::typhonql::RunUsingCompiler",
                    		Collections.emptyMap(),
							VF.string(preparedStatement),
							columnsWriter.done(),
							lw.done(),
							xmiModel,
							session);
				}
			} catch (StaticError e) {
				staticErrorMessage(evaluator.getStdErr(), e, VALUE_PRINTER);
				throw e;
			} catch (Throw e) {
				throwMessage(evaluator.getStdErr(), e, VALUE_PRINTER);
				throw e;
			} catch (Throwable e) {
				throwableMessage(evaluator.getStdErr(), e, evaluator.getStackTrace(), VALUE_PRINTER);
				throw e;
			}
		});
	}
	
	@Override
	public void resetDatabases() {
		evaluators.useAndReturn(evaluator -> {
			try {
				synchronized (evaluator) {
					// str src, str polystoreId, Schema s,
					return evaluator.call("runSchema", 
							"lang::typhonql::Run",
                    		Collections.emptyMap(),
                    		xmiModel, connections);
				}
			} catch (StaticError e) {
				staticErrorMessage(evaluator.getStdErr(), e, VALUE_PRINTER);
				throw e;
			} catch (Throw e) {
				throwMessage(evaluator.getStdErr(), e, VALUE_PRINTER);
				throw e;
			} catch (Throwable e) {
				throwableMessage(evaluator.getStdErr(), e, evaluator.getStackTrace(), VALUE_PRINTER);
				throw e;
			}
		});
	}

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

	private IMap buildConnections(List<DatabaseInfo> connectionInfo) {
		IMapWriter mw = VF.mapWriter();
		TypeStore ts = new TypeStore();
		Type connectionType = TF.abstractDataType(ts, "Connection");
		Type mariaDbType = TF.constructor(ts, connectionType, "sqlConnection", 
				TF.stringType(), "host", TF.integerType(), "port", TF.stringType(), "user",
				TF.stringType(), "password");
		Type mongoType = TF.constructor(ts, connectionType, "mongoConnection", 
				TF.stringType(), "host", TF.integerType(), "port", TF.stringType(), "user",
				TF.stringType(), "password");

		for (DatabaseInfo info : connectionInfo) {
			IString host = VF.string(info.getHost());
			IInteger port = VF.integer(info.getPort());
			IString user = VF.string(info.getUser());
			IString password = VF.string(info.getPassword());
			IString dbName = VF.string(info.getDbName());
			switch (info.getDbType()) { 
			case relationaldb:
				IValue v = VF.constructor(mariaDbType, host, port, user, password);
				mw.put(dbName, VF.constructor(mariaDbType, host, port, user, password));
				break;
			case documentdb:
				mw.put(dbName, VF.constructor(mongoType, host, port, user, password));
				break;
			}
		}
		return mw.done();
	}
	
	private ITuple createSession(Evaluator evaluator) {
		return sessionBuilder.newSession(connections, evaluator);
	}
	
	@Override
	public CommandResult[] executePreparedUpdate(String preparedStatement, String[] columnNames, String[][] values) {
		IValue v = evaluatePreparedStatementQuery(preparedStatement, columnNames, values);
		Iterator<IValue> iter0 = ((IList) v).iterator();
		List<CommandResult> results = new ArrayList<CommandResult>();
		while (iter0.hasNext()) {
			IValue val = iter0.next();
			results.add(CommandResult.fromIValue(val));		
		}
		return results.toArray(new CommandResult[0]);
	}
	
	public static void main(String[] args) throws IOException, URISyntaxException {
		DatabaseInfo[] infos = new DatabaseInfo[] {
				new DatabaseInfo("localhost", 27017, "Reviews", DBType.documentdb, new MongoDB().getName(),
						"admin", "admin"),
				new DatabaseInfo("localhost", 3306, "Inventory", DBType.relationaldb, new MariaDB().getName(),
						"root", "example") };
		
		if (args == null || args.length != 1 && args[0] == null) {
			System.out.println("Provide XMI file name");
			System.exit(-1);
		}
			
		String fileName = args[0];
		
		String xmiString = String.join("\n", Files.readAllLines(Paths.get(new URI(fileName))));

		PolystoreConnection conn = new XMIPolystoreConnection(xmiString, Arrays.asList(infos));
		ResultTable iv = conn.executeQuery("from Product p select p");
		System.out.println(iv);

	}

}

