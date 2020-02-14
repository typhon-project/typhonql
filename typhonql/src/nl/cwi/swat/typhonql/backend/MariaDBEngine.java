package nl.cwi.swat.typhonql.backend;

import java.util.LinkedHashMap;

public class MariaDBEngine extends Engine {

	private String host;
	private int port;
	private String dbName;
	private String user;
	private String password;

	public MariaDBEngine(ResultStore store, String host, int port, String dbName, String user, String password) {
		super(store);
		this.host = host;
		this.port = port;
		this.dbName = dbName;
		this.user = user;
		this.password = password;
		initializeDriver();
	}
	
	private void initializeDriver() {
		try {
			Class.forName("org.mariadb.jdbc.Driver");
		} catch (ClassNotFoundException e) {
			throw new RuntimeException("MariaDB driver not found", e);
		}
	}

	private String getConnectionString(String host, int port, String dbName, String user, String password) {
		return "jdbc:mariadb://" + host + ":" + port + "/" + dbName + "?user=" + user + "&password=" + password;
	}

	public void executeSelect(String resultId, String query) {
		this.storeResults(resultId, executeSelect(query, new LinkedHashMap<String, Binding>()));
	}
	
	public void executeSelect(String resultId, String query, LinkedHashMap<String, Binding> bindings) {
		this.storeResults(resultId, executeSelect(query, bindings));
	}
	
	private ResultIterator executeSelect(String query, LinkedHashMap<String, Binding> bindings) {
		return new MariaDBQueryExecutor(store, query, bindings, getConnectionString(host, port, dbName, user, password)).executeSelect();
	}

}
