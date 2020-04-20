package nl.cwi.swat.typhonql.backend.test;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import com.mongodb.client.MongoDatabase;

public interface BackendTestCommon {

	public static Connection getConnection(String host, int port, String dbName, String user, String password)
			throws SQLException {

		try {
			Class.forName("org.mariadb.jdbc.Driver");
		} catch (ClassNotFoundException e) {
			throw new RuntimeException("MariaDB driver not found", e);
		}
		Connection conn = DriverManager
				.getConnection(getMariaDBConnectionString("localhost", 3306, "Inventory", "root", "example"));
		return conn;
	}

	public static String getMariaDBConnectionString(String host, int port, String dbName, String user, String password) {
		return "jdbc:mariadb://" + host + ":" + port + "/" + dbName + "?user=" + user + "&password=" + password;
	}
	
	public static String getMongoDbConnectionString(String host, int port, String user, String password) {
		return "mongodb://" + user + ":" + password + "@" + host + ":" + port;
	}

	public static MongoDatabase getMongoDatabase(String host, int port, String dbName, String user, String password) {
		MongoClient client = MongoClients.create(getMongoDbConnectionString(host, port, user, password));
		return client.getDatabase(dbName);
		
	}
}
