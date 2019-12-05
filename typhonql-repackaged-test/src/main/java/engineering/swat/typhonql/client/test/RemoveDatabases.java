package engineering.swat.typhonql.client.test;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;

import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;

import nl.cwi.swat.typhonql.DBMS;
import nl.cwi.swat.typhonql.MariaDB;
import nl.cwi.swat.typhonql.MongoDB;

public class RemoveDatabases {

	public static void main(String[] args) {
		//"jdbc:mariadb://localhost:3306/RelationalDatabase?user=root&password=example"
		DBMS ms1 = new MariaDB();
		
		try {
			Connection conn = DriverManager.getConnection(ms1.getConnectionString("localhost", 3306, "RelationalDatabase", "root", "example"));
			Statement stmt = conn.createStatement();
			int result = stmt.executeUpdate("DROP DATABASE RelationalDatabase");
			System.out.println("db deleted");
			
			DBMS ms2 = new MongoDB();
			String connString = ms2.getConnectionString("localhost", 27017, "DocumentDatabase", "admin", "admin");
			MongoClient mongoClient = MongoClients.create(connString);
			mongoClient.getDatabase("DocumentDatabase").drop();
		} catch (SQLException e) {
			e.printStackTrace();
		}
	}
}
