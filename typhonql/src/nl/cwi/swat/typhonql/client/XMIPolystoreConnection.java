/********************************************************************************
* Copyright (c) 2018-2020 CWI & Swat.engineering 
*
* This program and the accompanying materials are made available under the
* terms of the Eclipse Public License 2.0 which is available at
* http://www.eclipse.org/legal/epl-2.0.
*
* This Source Code may also be made available under the following Secondary
* Licenses when the conditions for such availability set forth in the Eclipse
* Public License, v. 2.0 are satisfied: GNU General Public License, version 2
* with the GNU Classpath Exception which is
* available at https://www.gnu.org/software/classpath/license.html.
*
* SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0
********************************************************************************/

package nl.cwi.swat.typhonql.client;

import static org.rascalmpl.interpreter.utils.ReadEvalPrintDialogMessages.staticErrorMessage;
import static org.rascalmpl.interpreter.utils.ReadEvalPrintDialogMessages.throwMessage;
import static org.rascalmpl.interpreter.utils.ReadEvalPrintDialogMessages.throwableMessage;

import java.io.IOException;
import java.io.InputStream;
import java.io.PrintWriter;
import java.net.URI;
import java.net.URISyntaxException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import java.util.function.BiFunction;
import java.util.function.Function;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

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

import io.usethesource.vallang.IList;
import io.usethesource.vallang.IListWriter;
import io.usethesource.vallang.ISourceLocation;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.io.StandardTextWriter;
import nl.cwi.swat.typhonql.backend.ExternalArguments;
import nl.cwi.swat.typhonql.backend.rascal.SessionWrapper;
import nl.cwi.swat.typhonql.backend.rascal.TyphonSession;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

public class XMIPolystoreConnection {
	private static final StandardTextWriter VALUE_PRINTER = new StandardTextWriter(true, 2);
	private static final IValueFactory VF = ValueFactoryFactory.getValueFactory();

	private final ConcurrentSoftReferenceObjectPool<Evaluator> evaluators;
	private final TyphonSession sessionBuilder;
	
	public XMIPolystoreConnection() throws IOException {
		this.sessionBuilder = new TyphonSession(VF);
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
			Evaluator result = new Evaluator(ValueFactoryFactory.getValueFactory(), System.in, 
					System.err, System.out, new ModuleEnvironment("$typhonql$", heap), heap);

			result.addRascalSearchPathContributor(StandardLibraryContributor.getInstance());
			result.addRascalSearchPath(pcfg.getBin());
			for (IValue path : pcfg.getSrcs()) {
				result.addRascalSearchPath((ISourceLocation) path); 
			}
			result.addClassLoader(cl);

			long start = System.nanoTime();
			System.out.println("Starting a fresh evaluator to interpret the query (" + Integer.toHexString(System.identityHashCode(result)) + ")");
			System.out.flush();
			// now we are ready to import our main module
			result.doImport(null, "lang::typhonql::RunUsingCompiler");
			result.doImport(null, "lang::typhonql::Session");
			long stop = System.nanoTime();
			System.out.println("Finished initializing evaluator: " + Integer.toHexString(System.identityHashCode(result)) + " in " + TimeUnit.NANOSECONDS.toMillis(stop - start) + "ms");
			System.out.flush();
			return result;
		});
	}
	
	
	public ResultTable executeQuery(String xmiModel, List<DatabaseInfo> connections, String query) {
		return sessionCall(connections, Collections.emptyMap(), (session, evaluator) -> 
            (ResultTable) evaluator.call("runQueryAndGetJava", 
                "lang::typhonql::RunUsingCompiler",
                Collections.emptyMap(),
                VF.string(query), 
                VF.string(xmiModel),
                session.getTuple())
		);
	}
	
	private static void throwRascalMessage(PrintWriter errorPrinter, Throw e, StandardTextWriter valuePrinter) {
		IValue actual = e.getException();
		if (actual instanceof IString) {
			errorPrinter.append("TyphonQL failed to handle request, msg:\n");
			errorPrinter.append(((IString) actual).getValue());
			errorPrinter.append("\nTrace:\n");
		}
        throwMessage(errorPrinter, e, VALUE_PRINTER);
	}


	public ResultTable executeGetEntity(String xmiModel, List<DatabaseInfo> connections, String entity, String uuid) {
		return sessionCall(connections, Collections.emptyMap(), (session, evaluator) -> 
            (ResultTable) evaluator.call("runGetEntity", 
                "lang::typhonql::RunUsingCompiler",
                Collections.emptyMap(),
                VF.string(entity), 
                VF.string(uuid), 
                VF.string(xmiModel),
                session.getTuple())
        );
	}
	
	public ResultTable executeListEntities(String xmiModel, List<DatabaseInfo> connections, String entity, String whereClause, String limit, String sortBy) {
		return sessionCall(connections, Collections.emptyMap(), (session, evaluator) -> 
            (ResultTable) evaluator.call("listEntities", 
                "lang::typhonql::RunUsingCompiler",
                Collections.emptyMap(),
                VF.string(entity), 
                VF.string(whereClause!=null?whereClause:""),
                VF.string(limit!=null?limit:""),
                VF.string(sortBy!=null?sortBy:""),
                VF.string(xmiModel),
                session.getTuple())
        );
	}
	
	public void executeDDLUpdate(String xmiModel, List<DatabaseInfo> connections, String update) {
		sessionCall(connections, Collections.emptyMap(), (session, evaluator) -> 
            evaluator.call("runDDL", 
                "lang::typhonql::RunUsingCompiler",
                Collections.emptyMap(),
                VF.string(update), 
                VF.string(xmiModel),
                session.getTuple())
        );
		
	}
	
	public CommandResult executeUpdate(String xmiModel, List<DatabaseInfo> connections, Map<String, InputStream> blobMap, String query) {
		IValue val = evaluateUpdate(xmiModel, connections, blobMap, query);
		return CommandResult.fromIValue(val);
	}
	
	
	private IValue evaluateUpdate(String xmiModel, List<DatabaseInfo> connections, Map<String, InputStream> blobMap, String update) {
		return sessionCall(connections, blobMap, (session, evaluator) -> 
			evaluator.call("runUpdate", 
				"lang::typhonql::RunUsingCompiler",
				Collections.emptyMap(),
				VF.string(update), 
				VF.string(xmiModel),
				session.getTuple())
        );
	}
	

	private IValue evaluatePreparedStatementQuery(String xmiModel, List<DatabaseInfo> connections, Map<String, InputStream> blobMap, String preparedStatement, String[] columnNames, String[] columnTypes, String[][] matrix) {
		ExternalArguments externalArguments = buildExternalArguments(columnNames, columnTypes, matrix);

		IListWriter columnsWriter = VF.listWriter();
		for (String column : columnNames) {
			columnsWriter.append(VF.string(column));
		}
        return sessionCall(connections, blobMap, externalArguments, (session, evaluator) -> 
        	evaluator.call("runUpdate", 
                    "lang::typhonql::RunUsingCompiler",
                    Collections.emptyMap(),
                    VF.string(preparedStatement),
                    VF.string(xmiModel),
                    session.getTuple())
        );
	}
	




	private static Map<String, String> ESCAPES;
	
	static {
		ESCAPES = new HashMap<>();
		ESCAPES.put("\n", "\\n");
		ESCAPES.put("\r", "\\r");
		ESCAPES.put("\f", "\\f");
		ESCAPES.put("\t", "\\t");
		ESCAPES.put("\b", "\\b");
		ESCAPES.put("\"", "\\\"");
		ESCAPES.put("\\", "\\\\");
	}

	private static Pattern SPECIAL_CHARS = Pattern.compile("[\"\\\\\\n\\t\\r\\x08]");
	private static String escapeQL(String s) {
		Matcher specials = SPECIAL_CHARS.matcher(s);
		if (!specials.find()) {
			return s;
		}
		StringBuffer result = new StringBuffer(s.length() * 2);
		do {
			specials.appendReplacement(result, Matcher.quoteReplacement(ESCAPES.get(specials.group())));
		} while(specials.find());
		return specials.appendTail(result).toString();
	}
	
	private static final Map<String, Function<String, IValue>> qlRascalValueMappers;
	static {
		final IString QUOTE = VF.string('"');
		final IString DOLLAR = VF.string('$');
		final IString POUND = VF.string('#');
		qlRascalValueMappers = new HashMap<>();
		qlRascalValueMappers.put("int", VF::string);
		qlRascalValueMappers.put("bigint", VF::string);
		qlRascalValueMappers.put("float", VF::string);
		qlRascalValueMappers.put("string", s -> QUOTE.concat(VF.string(s)).concat(QUOTE));
		qlRascalValueMappers.put("bool", VF::string);
		qlRascalValueMappers.put("text", VF::string);
		qlRascalValueMappers.put("date", s -> DOLLAR.concat(VF.string(s)).concat(DOLLAR));
		qlRascalValueMappers.put("datetime", s -> DOLLAR.concat(VF.string(s)).concat(DOLLAR));
		qlRascalValueMappers.put("point", s -> POUND.concat(VF.string(s.toLowerCase())));
		qlRascalValueMappers.put("polygon", s -> POUND.concat(VF.string(s.toLowerCase())));
		qlRascalValueMappers.put("uuid", s -> POUND.concat(VF.string(s.toLowerCase())));
	}
	
	private static IList buildBoundRowValues(String[] columnTypes, String[][] matrix) {
		List<Function<String, IValue>> mappedColumns
			= new ArrayList<>(columnTypes.length);
		for (String ct : columnTypes) {
			Function<String, IValue> mapper = qlRascalValueMappers.get(ct);
			if (mapper == null) {
				throw new RuntimeException("Unknown type: " + ct 
						+ " not in: " + qlRascalValueMappers.keySet());
			}
			mappedColumns.add(mapper);
		}
		IListWriter result = VF.listWriter();
		for (String[] row: matrix) {
			IListWriter rowList = VF.listWriter();
			for (int c = 0; c < row.length; c++) {
				rowList.append(mappedColumns.get(c).apply(row[c]));
			}
			result.append(rowList.done());
		}
		return result.done();
	}
	
	private static final Map<String, Function<String, Object>> qlValueMappers;
	static {
		qlValueMappers = new HashMap<>();
		qlValueMappers.put("int",Integer::parseInt);
		qlValueMappers.put("string", s -> s);
		qlValueMappers.put("bool", Boolean::valueOf);
		qlValueMappers.put("text", s -> s);
		qlValueMappers.put("uuid", UUID::fromString);
	}
	
	
	public static ExternalArguments buildExternalArguments(String[] columnNames, String[] columnTypes, String[][] matrix) {
		Object[][] values = new Object[matrix.length][];
		for (int i =0; i < matrix.length; i++) {
			String[] row = matrix[i];
			Object[] vs = new Object[row.length];
			for (int j=0; j < row.length; j++) {
				Function<String, Object> mapper = qlValueMappers.get(columnTypes[j]);
				if (mapper == null) {
					throw new RuntimeException("Unknown type: " + columnTypes[j] 
							+ " not in: " + qlValueMappers.keySet());
				}
				vs[j] = mapper.apply(row[j]);
			}
			values[i] = vs; 
		}
		return new ExternalArguments(columnNames, values);
	}


	public void resetDatabases(String xmiModel, List<DatabaseInfo> connections) {
        sessionCall(connections, Collections.emptyMap(), (session, evaluator) -> 
            evaluator.call("runSchema", 
                "lang::typhonql::RunUsingCompiler",
                Collections.emptyMap(),
                VF.string(xmiModel), 
                session.getTuple())
        );
	}

	private <R> R sessionCall(List<DatabaseInfo> connections, Map<String, InputStream> blobs, BiFunction<SessionWrapper, Evaluator, R> exec) {
		return sessionCall(connections, blobs, new ExternalArguments(), exec);
	}
	
	private <R> R sessionCall(List<DatabaseInfo> connections, Map<String, InputStream> blobs, ExternalArguments externalArguments, BiFunction<SessionWrapper, Evaluator, R> exec) {
		return evaluators.useAndReturn(evaluator -> {
			try (SessionWrapper session = sessionBuilder.newSessionWrapper(connections, Collections.emptyMap(), externalArguments, evaluator)) {
				synchronized (evaluator) {
					return exec.apply(session, evaluator);
				}
			} catch (StaticError e) {
				staticErrorMessage(evaluator.getErrorPrinter(), e, VALUE_PRINTER);
				throw e;
			} catch (Throw e) {
				throwRascalMessage(evaluator.getErrorPrinter(), e, VALUE_PRINTER);
				throw e;
			} catch (Throwable e) {
				throwableMessage(evaluator.getErrorPrinter(), e, evaluator.getStackTrace(), VALUE_PRINTER);
				throw new RuntimeException(e);
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
	
	public CommandResult[] executePreparedUpdate(String xmiModel, List<DatabaseInfo> connections, Map<String, InputStream> fileMap, String preparedStatement, String[] columnNames, String[] columnTypes, String[][] values) {
		IValue v = evaluatePreparedStatementQuery(xmiModel, connections, fileMap, preparedStatement, columnNames, columnTypes, values);
		Iterator<IValue> iter0 = ((IList) v).iterator();
		List<CommandResult> results = new ArrayList<CommandResult>();
		while (iter0.hasNext()) {
			IValue val = iter0.next();
			results.add(CommandResult.fromIValue(val));		
		}
		return results.toArray(new CommandResult[0]);
	}
	
	public static void main(String[] args) throws IOException, URISyntaxException {

//		public DatabaseInfo(String host, int port, String dbName, String dbms, String user,
//				String password) {
//			
//		}
		DatabaseInfo[] infos = new DatabaseInfo[] {
				new DatabaseInfo("localhost", 27017, "Reviews","mongodb",  "",
						"admin", "admin"),
				new DatabaseInfo("localhost", 3306, "Inventory", "mariadb", "",
						"root", "example") };
		
		if (args == null || args.length != 1 && args[0] == null) {
			System.out.println("Provide XMI file name");
			System.exit(-1);
		}
			
		String fileName = args[0];
		
		String xmiString = String.join("\n", Files.readAllLines(Paths.get(new URI(fileName))));

		XMIPolystoreConnection conn = new XMIPolystoreConnection();
		ResultTable iv = conn.executeQuery(xmiString, Arrays.asList(infos), "from Product p select p");
		System.out.println(iv);

	}

}
