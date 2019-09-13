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
}
