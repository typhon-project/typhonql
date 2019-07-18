package nl.cwi.swat.typhonql;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
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
	
	private static boolean booted = false;
	
	public static Connections getInstance() {
		if (!booted) {
			boot();
		}
		return instance;
	}
	
	public static void boot() {
		instance = new Connections();
		booted = true;
	}
	
	public Object getConnection(String dbName) {
		return connections.get(dbName);
	}
	
	private Connections() {
		this.connections = new HashMap<String, Object>();
		initialize();
	}

	private void initialize() {
		try {
			Class.forName("org.sqlite.JDBC");
			Connection connection = null;
			connection = DriverManager.getConnection("jdbc:sqlite:sample.db");
			
			// schema specific, for now
			connections.put("RelationalDB", connection);
			
		} catch (ClassNotFoundException | SQLException e) {
			e.printStackTrace();
		}
		
		
		MongoClient mongoClient = MongoClients.create("mongodb://localhost:27017");
		MongoDatabase db = mongoClient.getDatabase("test");
		connections.put("DocumentDB", db);
	}

}
