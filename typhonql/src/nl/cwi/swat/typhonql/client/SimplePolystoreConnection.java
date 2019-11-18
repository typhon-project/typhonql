package nl.cwi.swat.typhonql.client;

import static org.rascalmpl.interpreter.utils.ReadEvalPrintDialogMessages.staticErrorMessage;
import static org.rascalmpl.interpreter.utils.ReadEvalPrintDialogMessages.throwMessage;
import static org.rascalmpl.interpreter.utils.ReadEvalPrintDialogMessages.throwableMessage;

import java.io.IOException;
import java.io.PrintWriter;
import java.util.Collections;
import java.util.List;

import org.rascalmpl.interpreter.control_exceptions.Throw;
import org.rascalmpl.interpreter.staticErrors.StaticError;

import io.usethesource.vallang.IValue;
import io.usethesource.vallang.impl.persistent.ValueFactory;
import io.usethesource.vallang.io.StandardTextWriter;

public class SimplePolystoreConnection extends BasePolystoreConnection {

	private static final PrintWriter ERROR_WRITER = new PrintWriter(System.err);
	private static final StandardTextWriter VALUE_PRINTER = new StandardTextWriter(true, 2);
	
	private final PolystoreSchema schema;

	public SimplePolystoreConnection(PolystoreSchema schema, List<DatabaseInfo> infos) throws IOException {
		super(infos);
		this.schema = schema;

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
                            schema.asRascalValue());
                }
			}
			catch (StaticError e) {
				staticErrorMessage(ERROR_WRITER,e, VALUE_PRINTER);
				throw e;
			}
			catch (Throw e) {
				throwMessage(ERROR_WRITER,e, VALUE_PRINTER);
				throw e;
			}
			catch (Throwable e) {
				throwableMessage(ERROR_WRITER, e, evaluator.getStackTrace(), VALUE_PRINTER);
				throw e;
			}
		});
	}

	@Override
	public void resetDatabases() {
		throw new UnsupportedOperationException();
		
	}
}
