package nl.cwi.swat.typhonql.backend.rascal;

import io.usethesource.vallang.type.TypeFactory;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

public class TyphonSessionState {
	private static TypeFactory TF = TypeFactory.getInstance();
	
	private boolean finalized = false;
	private ResultTable result = null;

	public void close() {
		this.finalized = true;
		this.result = null;
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
	
}
