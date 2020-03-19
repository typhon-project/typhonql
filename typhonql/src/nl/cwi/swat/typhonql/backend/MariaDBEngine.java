package nl.cwi.swat.typhonql.backend;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

import nl.cwi.swat.typhonql.backend.rascal.Path;

public class MariaDBEngine extends Engine {

	private String host;
	private int port;
	private String dbName;
	private String user;
	private String password;

	public MariaDBEngine(ResultStore store, List<Consumer<List<Record>>> script, Map<String, String> uuids, String host, int port, String dbName, String user, String password) {
		super(store, script, uuids);
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
	
	public void executeSelect(String resultId, String query, List<Path> signature) {
		new MariaDBQueryExecutor(store, script, uuids, signature, query, new HashMap<String, Binding>(), getConnectionString(host, port, dbName, user, password)).executeSelect(resultId);
	}

	public void executeSelect(String resultId, String query, Map<String, Binding> bindings, List<Path> signature) {
		new MariaDBQueryExecutor(store, script, uuids, signature, query, bindings, getConnectionString(host, port, dbName, user, password)).executeSelect(resultId);
	}

	public void executeUpdate(String query, Map<String, Binding> bindings) {
		new MariaDBUpdateExecutor(store, uuids, query, bindings, getConnectionString(host, port, dbName, user, password)).executeUpdate();		
	}

}
