package nl.cwi.swat.typhonql;

public class MySQL implements DBMS {

	@Override
	public String getName() {
		return "MySQLDB";
	}
	
	@Override
	public String getConnectionString(String host, int port, String dbName, String user, String password) {
		return "jdbc:mysql://" + host + ":" + port + "/" + dbName + "?user=" + user + "&password=" + password;
	}

	@Override
	public void initializeDriver() {
		try {
			Class.forName("com.mysql.jdbc.Driver");
		} catch (ClassNotFoundException e) {
			throw new RuntimeException("MySQL driver not found", e);
		}
		
	}
}
