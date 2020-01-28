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

	@Override
	protected QueryExecutor getExecutor(String resultId, String query, LinkedHashMap<String, Binding> bindings) {
		return new MongoQueryExecutor(getConnectionString(host, port, user, password), dbName, query, bindings, store);
	}
	
	private String getConnectionString(String host, int port, String user, String password) {
		return "mongodb://" + user + ":" + password + "@" + host + ":" + port;
	}



}
