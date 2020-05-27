package nl.cwi.swat.typhonql.backend.rascal;

import java.util.ArrayList;
import java.util.List;
import nl.cwi.swat.typhonql.backend.Closables;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

public class TyphonSessionState implements AutoCloseable {
	
	private boolean finalized = false;
	private ResultTable result = null;

	private final List<AutoCloseable> operations = new ArrayList<>();


	@Override
	public void close() throws Exception {
        this.finalized = true;
        this.result = null;
        Closables.autoCloseAll(operations, Exception.class);
	}

	public ResultTable getResult() {
		return result;
	}

	public void setResult(ResultTable result) {
		this.result = result;
	}

	public boolean isFinalized() {
		return finalized;
	}
	
	public void addOpperations(AutoCloseable op) {
		operations.add(op);
	}
}
