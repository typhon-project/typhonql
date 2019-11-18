package nl.cwi.swat.typhonql.backend;

public class MariaDBEngine extends SQLEngine {

	public MariaDBEngine(ResultStore store, String host, int port, String dbName, String user, String password) {
		super(store, host, port, dbName, user, password);
	}

	@Override
	protected void initializeDriver() {
		try {
			Class.forName("org.mariadb.jdbc.Driver");
		} catch (ClassNotFoundException e) {
			throw new RuntimeException("MariaDB driver not found", e);
		}		
	}
	
	@Override
	public String getConnectionString(String host, int port, String dbName, String user, String password) {
		return "jdbc:mariadb://" + host + ":" + port + "/" + dbName + "?user=" + user + "&password=" + password;
	}

}
