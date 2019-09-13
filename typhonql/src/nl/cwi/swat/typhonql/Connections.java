package nl.cwi.swat.typhonql;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.HashMap;
import java.util.Map;

import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import com.mongodb.client.MongoDatabase;

public class Connections {
// singleton to provide connections to the Bridge
// should be configured from the polystore API

	private final Map<String, Object> connections;

	private static Connections instance;

	private static boolean booted;

	public static Connections getInstance() {
		if (!booted) {
			throw new RuntimeException("Connections have not been initialized");
		}
		return instance;
	}

	public Object getConnection(String dbName) {
		return connections.get(dbName);
	}

	private Connections() {
		this.connections = new HashMap<String, Object>();
	}
	
	public static void boot(ConnectionInfo[] infos) {
		instance = new Connections();
		for (ConnectionInfo info : infos)
			instance.addConnection(info);
		booted = true;
	}

	private void addConnection(ConnectionInfo info) {
		switch (info.getDbType()) {
		case relationaldb: {
			addRelationalConnection(info.getHost(), info.getPort(), info.getDbName(), 
					info.getDbms(), info.getUser(), info.getPassword());
			break;
		}
		case documentdb: {
			addDocumentConnection(info.getHost(), info.getPort(), info.getDbName(),
					info.getDbms(), info.getUser(), info.getPassword());
			break;
		}
		}
	}

	private void addDocumentConnection(String host, int port, String dbName,
			String dbms, String user, String password) {
		DBMS ms = DBType.documentdb.getDBMS(dbms);
		String connString = ms.getConnectionString(host, port, dbName, user, password);
		MongoClient mongoClient = MongoClients.create(connString);
		MongoDatabase db = mongoClient.getDatabase(dbName);
		connections.put(dbName, db);
	}

	private void addRelationalConnection(String host, int port, String dbName,
			String dbms, String user, String password) {
		DBMS ms = DBType.relationaldb.getDBMS(dbms);
		String connString = ms.getConnectionString(host, port, dbName, user, password);
		Connection connection = null;
		try {
			connection = DriverManager.getConnection(connString);
			connections.put(dbName, connection);
		} catch (SQLException e) {
			try {
				Connection conn = DriverManager.getConnection(ms.getConnectionString("localhost", 3306, "", "root", "example"));
				Statement stmt = conn.createStatement();
				int result = stmt.executeUpdate("CREATE DATABASE " + dbName);
				addRelationalConnection(host, port, dbName, dbms, user, password);
			} catch (SQLException e1) {
				throw new RuntimeException(e1);
			}
		}

	}

	public static void main(String[] args) {
		//"jdbc:mariadb://localhost:3306/RelationalDatabase?user=root&password=example"
		DBMS ms = DBType.relationaldb.getDBMS("MariaDB");
		
		try {
			Connection conn = DriverManager.getConnection(ms.getConnectionString("localhost", 3306, "RelationalDatabase", "root", "example"));
			System.out.println("conn created");
		} catch (SQLException e) {
			// Maybe database has not been created, try to create it
			try {
				Connection conn =DriverManager.getConnection(ms.getConnectionString("localhost", 3306, "", "root", "example"));
				Statement stmt = conn.createStatement();
				int result = stmt.executeUpdate("CREATE DATABASE RelationalDatabase");
				System.out.println("database created");
			} catch (SQLException e1) {
				e1.printStackTrace();
			}
			
		}
	}
}
