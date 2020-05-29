package nl.cwi.swat.typhonql.backend.test;

import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Arrays;
import nl.cwi.swat.typhonql.client.DatabaseInfo;
import nl.cwi.swat.typhonql.client.XMIPolystoreConnection;

public class ResetDatabase {

	public static void main(String[] args) throws IOException, URISyntaxException {
		DatabaseInfo[] infos = new DatabaseInfo[] {
				new DatabaseInfo("localhost", 27017, "Reviews", "mongodb",
						"admin", "admin"),
				new DatabaseInfo("localhost", 3306, "Inventory", "mariadb",
						"root", "example") };
		
		String fileName = "file:///Users/pablo/git/typhonql/typhonql/src/lang/typhonql/test/resources/user-review-product/user-review-product.xmi";
		
		String xmiString = String.join("\n", Files.readAllLines(Paths.get(new URI(fileName))));

		XMIPolystoreConnection conn = new XMIPolystoreConnection();
		
		conn.resetDatabases(xmiString, Arrays.asList(infos));
		
	}
	
}
