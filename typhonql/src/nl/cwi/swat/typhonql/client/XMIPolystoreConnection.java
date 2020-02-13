package nl.cwi.swat.typhonql.client;

import static org.rascalmpl.interpreter.utils.ReadEvalPrintDialogMessages.staticErrorMessage;
import static org.rascalmpl.interpreter.utils.ReadEvalPrintDialogMessages.throwMessage;
import static org.rascalmpl.interpreter.utils.ReadEvalPrintDialogMessages.throwableMessage;
import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;
import org.rascalmpl.interpreter.control_exceptions.Throw;
import org.rascalmpl.interpreter.staticErrors.StaticError;
import org.rascalmpl.values.ValueFactoryFactory;
import io.usethesource.vallang.IListWriter;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.io.StandardTextWriter;
import nl.cwi.swat.typhonql.DBType;
import nl.cwi.swat.typhonql.MariaDB;
import nl.cwi.swat.typhonql.MongoDB;
import nl.cwi.swat.typhonql.workingset.Entity;
import nl.cwi.swat.typhonql.workingset.WorkingSet;

public class XMIPolystoreConnection extends BasePolystoreConnection {
	private static final StandardTextWriter VALUE_PRINTER = new StandardTextWriter(true, 2);
	private static final IValueFactory VF = ValueFactoryFactory.getValueFactory();
	private static final IString LOCALHOST = VF.string("localhost");
	
	private volatile IString xmiModel;
	
	public XMIPolystoreConnection(String xmiModel, List<DatabaseInfo> infos) throws IOException {
		super(infos);
		this.xmiModel = VF.string(xmiModel);
	}
	
	public void setXmiModel(String xmiModel) {
		this.xmiModel = VF.string(xmiModel);
	}
	
	protected IValue evaluateQuery(String query) {
		return evaluators.useAndReturn(evaluator -> {
			try {
				synchronized (evaluator) {
					// str src, str polystoreId, Schema s,
					return evaluator.call("run", 
							"lang::typhonql::Run",
                    		Collections.emptyMap(),
							VF.string(query), 
							LOCALHOST, xmiModel);
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
	protected IValue evaluatePreparedStatementQuery(String preparedStatement, String[] columnNames, String[][] matrix) {
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
					// str src, str polystoreId, Schema s,
					return evaluator.call("runPrepared", 
							"lang::typhonql::Run",
                    		Collections.emptyMap(),
							VF.string(preparedStatement),
							LOCALHOST,
							columnsWriter.done(),
							lw.done(),
							xmiModel);
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
							LOCALHOST, xmiModel);
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