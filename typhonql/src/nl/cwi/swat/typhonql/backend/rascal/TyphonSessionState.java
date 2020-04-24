package nl.cwi.swat.typhonql.backend.rascal;

import io.usethesource.vallang.type.TypeFactory;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

public class TyphonSessionState implements AutoCloseable {
	private static TypeFactory TF = TypeFactory.getInstance();
	
	private boolean finalized = false;
	private ResultTable result = null;

	private MariaDBOperations mariaDbOperations;

	private MongoOperations mongoOperations;


	@Override
	public void close() {
		try {
            this.finalized = true;
            this.result = null;
            if (mariaDbOperations != null) {
            	mariaDbOperations.close();
            }
		}
		finally {
			// make sure mongoOperations are also closed, even if mariadb operations fail to close
            if (mongoOperations != null) {
            	mongoOperations.close();
            }
		}
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

	public void setMariaDBOperations(MariaDBOperations mariaDBOperations) {
		this.mariaDbOperations = mariaDBOperations;
		
	}

	public void setMongoOperations(MongoOperations mongoOperations) {
		this.mongoOperations = mongoOperations;
		
	}
	
}
