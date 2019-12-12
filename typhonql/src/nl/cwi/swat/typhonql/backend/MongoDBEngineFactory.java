package nl.cwi.swat.typhonql.backend;

public class MongoDBEngineFactory implements EngineFactory {

	@Override
	public Engine createEngine(ResultStore store, String host, int port, String dbName, String user, String password) {
		return new MongoDBEngine(store, host, port, dbName, user, password);
	}

}
