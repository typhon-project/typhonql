package nl.cwi.swat.typhonql.backend;

public interface EngineFactory {
	Engine createEngine(ResultStore store, String host, int port, String dbName, String user, String password);
}
