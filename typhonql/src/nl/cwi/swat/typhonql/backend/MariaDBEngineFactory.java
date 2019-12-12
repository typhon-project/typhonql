package nl.cwi.swat.typhonql.backend;

public class MariaDBEngineFactory implements EngineFactory {

	@Override
	public Engine createEngine(ResultStore store, String host, int port, String dbName, String user, String password) {
		return new MariaDBEngine(store, host, port, dbName, user, password);
	}

}
