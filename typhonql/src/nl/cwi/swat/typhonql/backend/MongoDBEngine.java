package nl.cwi.swat.typhonql.backend;

import java.util.LinkedHashMap;

public class MongoDBEngine extends Engine {
	private String host;
	private int port;
	private String dbName;
	private String user;
	private String password;

	public MongoDBEngine(ResultStore store, String host, int port, String dbName, String user, String password) {
		super(store);
		this.host = host;
		this.port = port;
		this.dbName = dbName;
		this.user = user;
		this.password = password;
	}
	
	private String getConnectionString(String host, int port, String user, String password) {
		return "mongodb://" + user + ":" + password + "@" + host + ":" + port;
	}

	public void executeFind(String resultId, String collectionName, String query, LinkedHashMap<String, Binding> bindings) {
		ResultIterator results = new MongoQueryExecutor(store, collectionName, query, bindings, getConnectionString(host, port, user, password), dbName).executeSelect();
		storeResults(resultId, results);
	}

}
