package nl.cwi.swat.typhonql;

public class MariaDB implements DBMS {

	@Override
	public String getName() {
		return "MariaDB";
	}

	@Override
	public String getConnectionString(String host, int port, String dbName, String user, String password) {
		return "jdbc:mariadb://" + host + ":" + port + "/" + dbName + "?user=" + user + "&password=" + password;
	}

	@Override
	public void initializeDriver() {
		try {
			Class.forName("org.mariadb.jdbc.Driver");
		} catch (ClassNotFoundException e) {
			throw new RuntimeException("MariaDB driver not found", e);
		}
		
	}
}
