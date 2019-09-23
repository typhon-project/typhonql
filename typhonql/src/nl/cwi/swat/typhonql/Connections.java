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

	private final Map<String, Map<String, Object>> connections;
	
	// TODO This is a temporary workaround. Think of a better way of keeping JDBC connections alive
	private final Map<String, Map<String, Runnable>> relationalClosures;

	private static Connections instance;

	private static boolean booted;

	public static Connections getInstance() {
		if (!booted) {
			throw new RuntimeException("Connections have not been initialized");
		}
		return instance;
	}

	public Object getConnection(String polystoreId, String dbName) {
		Map<String, Object> perPolystore = connections.get(polystoreId);
		if (perPolystore != null) {
			Object conn = perPolystore.get(dbName);
			if (conn instanceof Connection)
				conn = checkConnectionAlive((Connection) conn, polystoreId, dbName);
			return conn;
		}
		else
			return null;
	}

	private Object checkConnectionAlive(Connection con, String polystoreId, String dbName) {
		try {
			if (con.isValid(0)) {
				return con;
			}
			else {
				return refreshRelationalConnection(polystoreId, dbName);
			}
		} catch (SQLException e) {
			return refreshRelationalConnection(polystoreId, dbName);
		}
	}

	private Object refreshRelationalConnection(String polystoreId, String dbName) {
		Map<String, Runnable> perPolystore = relationalClosures.get(polystoreId);
		Runnable r = perPolystore.get(dbName);
		r.run();
		Object con = connections.getOrDefault(polystoreId, new HashMap<>()).getOrDefault(dbName, null);
		return con;
	}

	private Connections() {
		this.connections = new HashMap<>();
		this.relationalClosures = new HashMap<>();
	}
	
	public static void boot(ConnectionInfo[] infos) {
		instance = new Connections();
		for (ConnectionInfo info : infos)
			instance.addConnection(info);
		booted = true;
	}

	private void addConnection(ConnectionInfo info) {
		if (info.getDbType() == null)
			throw new RuntimeException("Database type not known");
		switch (info.getDbType()) {
		case relationaldb: {
			Runnable r = () ->
				addRelationalConnection(info.getPolystoreId(), info.getHost(), info.getPort(), info.getDbName(), 
					info.getDbms(), info.getUser(), info.getPassword());
			relationalClosures.putIfAbsent(info.getPolystoreId(), new HashMap<String, Runnable>());
			relationalClosures.get(info.getPolystoreId()).put(info.getDbName(), r);
			addRelationalConnection(info.getPolystoreId(), info.getHost(), info.getPort(), info.getDbName(), 
						info.getDbms(), info.getUser(), info.getPassword());
			break;
		}
		case documentdb: {
			addDocumentConnection(info.getPolystoreId(), info.getHost(), info.getPort(), info.getDbName(),
					info.getDbms(), info.getUser(), info.getPassword());
			break;
		}
		}
	}

	private void addDocumentConnection(String polystoreId, String host, int port, String dbName,
			String dbms, String user, String password) {
		DBMS ms = DBType.documentdb.getDBMS(dbms);
		String connString = ms.getConnectionString(host, port, dbName, user, password);
		MongoClient mongoClient = MongoClients.create(connString);
		MongoDatabase db = mongoClient.getDatabase(dbName);
		put(polystoreId, dbName, db); 
	}

	private void put(String polystoreId, String dbName, Object db) {
		Map<String, Object> perPolystore = null;
		if (!connections.containsKey(polystoreId)) {
			perPolystore = new HashMap<String, Object>();
			connections.put(polystoreId, perPolystore);
		}
		else 
			perPolystore = connections.get(polystoreId);
		perPolystore.put(dbName, db);
	}

	private void addRelationalConnection(String polystoreId, String host, int port, String dbName,
			String dbms, String user, String password) {
		DBMS ms = DBType.relationaldb.getDBMS(dbms);
		ms.initializeDriver();
		String connString = ms.getConnectionString(host, port, dbName, user, password);
		Connection connection = null;
		try {
			connection = DriverManager.getConnection(connString);
			put(polystoreId, dbName, connection);
		} catch (SQLException e) {
			try {
				Connection conn = DriverManager.getConnection(ms.getConnectionString("localhost", 3306, "", "root", "example"));
				Statement stmt = conn.createStatement();
				int result = stmt.executeUpdate("CREATE DATABASE " + dbName);
				addRelationalConnection(polystoreId, host, port, dbName, dbms, user, password);
			} catch (SQLException e1) {
				throw new RuntimeException(e1);
			}
		}

	}

	public static void main(String[] args) {
		//"jdbc:mariadb://localhost:3306/RelationalDatabase?user=root&password=example"
		DBMS ms = DBType.relationaldb.getDBMS("MySqlDB");
		
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
