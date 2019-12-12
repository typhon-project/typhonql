package nl.cwi.swat.typhonql.backend.rascal;

import java.util.Map;

import nl.cwi.swat.typhonql.backend.Engine;
import nl.cwi.swat.typhonql.backend.EngineFactory;
import nl.cwi.swat.typhonql.backend.ResultStore;

public class BackendRegistry {
	private static Map<String, EngineFactory> factories;
	
	public static void addEngineFactory(String engineType, EngineFactory factory) {
		factories.put(engineType.toUpperCase(), factory);
	}
	
	public static Engine createEngine(String dbType, ResultStore store, String host, int port, String dbName, String user, String password) {
		return factories.get(dbType.toUpperCase()).createEngine(store, host, port, dbName, user, password);
	}
}
