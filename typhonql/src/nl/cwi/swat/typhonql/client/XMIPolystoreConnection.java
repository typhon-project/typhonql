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
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import org.rascalmpl.interpreter.control_exceptions.Throw;
import org.rascalmpl.interpreter.staticErrors.StaticError;

import io.usethesource.vallang.IValue;
import io.usethesource.vallang.impl.persistent.ValueFactory;
import io.usethesource.vallang.io.StandardTextWriter;
import nl.cwi.swat.typhonql.DBType;
import nl.cwi.swat.typhonql.MariaDB;
import nl.cwi.swat.typhonql.MongoDB;
import nl.cwi.swat.typhonql.workingset.WorkingSet;

public class XMIPolystoreConnection extends BasePolystoreConnection {
	private static final PrintWriter ERROR_WRITER = new PrintWriter(System.err);
	private static final StandardTextWriter VALUE_PRINTER = new StandardTextWriter(true, 2);
	private static final String LOCALHOST = "localhost";
	
	private String xmiModel;
	
	public XMIPolystoreConnection(String xmiModel, List<DatabaseInfo> infos) throws IOException {
		super(infos);
		this.xmiModel = xmiModel;
	}



	protected IValue evaluateQuery(String query) {
		return evaluators.useAndReturn(evaluator -> {
			try {
				synchronized (evaluator) {
					// str src, str polystoreId, Schema s,
					return evaluator.call("run", 
							"lang::typhonql::Run",
                    		Collections.emptyMap(),
							ValueFactory.getInstance().string(query),
							ValueFactory.getInstance().string(LOCALHOST),
							ValueFactory.getInstance().string(xmiModel));
				}
			} catch (StaticError e) {
				staticErrorMessage(ERROR_WRITER, e, VALUE_PRINTER);
				throw e;
			} catch (Throw e) {
				throwMessage(ERROR_WRITER, e, VALUE_PRINTER);
				throw e;
			} catch (Throwable e) {
				throwableMessage(ERROR_WRITER, e, evaluator.getStackTrace(), VALUE_PRINTER);
				throw e;
			}
		});
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
		WorkingSet iv = conn.executeQuery("from Product p select p");
		System.out.println(iv);

	}
}