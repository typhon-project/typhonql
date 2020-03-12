package nl.cwi.swat.typhonql.backend;

import java.util.HashMap;
import java.util.Map;

public class MariaDBEngine extends Engine {

	private String host;
	private int port;
	private String dbName;
	private String user;
	private String password;

	public MariaDBEngine(ResultStore store, Map<String, String> uuids, String host, int port, String dbName, String user, String password) {
		super(store, uuids);
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
		this.storeResults(resultId, executeSelect(query, new HashMap<String, Binding>()));
	}
	
	public void executeSelect(String resultId, String query, Map<String, Binding> bindings) {
		this.storeResults(resultId, executeSelect(query, bindings));
	}
	
	private ResultIterator executeSelect(String query, Map<String, Binding> bindings) {
		return new MariaDBQueryExecutor(store, uuids, query, bindings, getConnectionString(host, port, dbName, user, password)).executeSelect();
	}

	public void executeUpdate(String query, Map<String, Binding> bindings) {
		new MariaDBUpdateExecutor(store, uuids, query, bindings, getConnectionString(host, port, dbName, user, password)).executeUpdate();		
	}

}
