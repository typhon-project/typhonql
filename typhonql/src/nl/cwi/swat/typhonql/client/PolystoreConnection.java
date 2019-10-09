package nl.cwi.swat.typhonql.client;

import java.io.IOException;
import java.net.JarURLConnection;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.URL;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.rascalmpl.interpreter.Evaluator;
import org.rascalmpl.interpreter.load.StandardLibraryContributor;
import org.rascalmpl.interpreter.load.URIContributor;

import io.usethesource.vallang.IList;
import io.usethesource.vallang.ISourceLocation;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.impl.persistent.ValueFactory;
import nl.cwi.swat.typhonql.ConnectionInfo;
import nl.cwi.swat.typhonql.Connections;
import nl.cwi.swat.typhonql.DBType;
import nl.cwi.swat.typhonql.MariaDB;
import nl.cwi.swat.typhonql.MongoDB;

public class PolystoreConnection {

	private static String LOCALHOST = "localhost";
	private PolystoreSchema schema;
	private Evaluator evaluator;

	public PolystoreConnection(PolystoreSchema schema, List<DatabaseInfo> infos, boolean insideJar) throws IOException {

		this.schema = schema;
		Connections.boot(infos.stream().map(i -> new ConnectionInfo(LOCALHOST, i)).collect(Collectors.toList())
				.toArray(new ConnectionInfo[0]));
		// Create Rascal intepreter
		evaluator = JavaRascalContext.getEvaluator();
		
		ISourceLocation moduleRoot;

		if (insideJar) {
			URL mainURL = PolystoreConnection.class.getClassLoader().getResource("lang/typhonql/Run.rsc");
			final JarURLConnection connection = (JarURLConnection) mainURL.openConnection();
			URL jarURL = connection.getJarFileURL();
			try {
				moduleRoot = ValueFactory.getInstance().sourceLocation("jar+file", null, jarURL.getFile() + "!/");
			} catch (URISyntaxException e) {
				System.out.println("This should never happen.");
				throw new RuntimeException(e);
			}
		} else {
			try {
				Path path = Paths.get(PolystoreConnection.class.getClassLoader().getResource("lang/typhonql/Run.rsc").toURI());
				URI mainURI = path.getParent().getParent().getParent().toUri();
				moduleRoot = ValueFactory.getInstance().sourceLocation(mainURI);
			} catch (URISyntaxException e) {
				System.out.println("This should never happen.");
				throw new RuntimeException(e);
			}
		}

		// Add project (with Rascal modules) to search path and import module
		evaluator.addRascalSearchPathContributor(StandardLibraryContributor.getInstance());
		evaluator.addRascalSearchPathContributor(new URIContributor(moduleRoot));

		evaluator.doImport(null, "lang::typhonql::Run");

	}

	public IValue executeQuery(String query) {
		// Call function (if the evaluator is shared it must be synchronized).
		synchronized (evaluator) {
			// str src, str polystoreId, Schema s,
			IValue r = evaluator.call("run", 
					ValueFactory.getInstance().string(query),
					ValueFactory.getInstance().string(LOCALHOST), 
					schema.asRascalValue());
			return r;

		}
	}
}
