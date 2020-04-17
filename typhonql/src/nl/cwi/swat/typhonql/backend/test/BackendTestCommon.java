package nl.cwi.swat.typhonql.backend.test;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

public interface BackendTestCommon {

	public static Connection getConnection(String host, int port, String dbName, String user, String password)
			throws SQLException {

		try {
			Class.forName("org.mariadb.jdbc.Driver");
		} catch (ClassNotFoundException e) {
			throw new RuntimeException("MariaDB driver not found", e);
		}
		Connection conn = DriverManager
				.getConnection(getConnectionString("localhost", 3306, "Inventory", "root", "example"));
		return conn;
	}

	public static String getConnectionString(String host, int port, String dbName, String user, String password) {
		return "jdbc:mariadb://" + host + ":" + port + "/" + dbName + "?user=" + user + "&password=" + password;
	}
}
