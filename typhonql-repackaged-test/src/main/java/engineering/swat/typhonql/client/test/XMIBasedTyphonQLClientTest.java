package engineering.swat.typhonql.client.test;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Arrays;

import nl.cwi.swat.typhonql.DBType;
import nl.cwi.swat.typhonql.MariaDB;
import nl.cwi.swat.typhonql.MongoDB;
import nl.cwi.swat.typhonql.client.DatabaseInfo;
import nl.cwi.swat.typhonql.client.PolystoreConnection;
import nl.cwi.swat.typhonql.client.XMIPolystoreConnection;
import nl.cwi.swat.typhonql.workingset.WorkingSet;
import nl.cwi.swat.typhonql.workingset.json.WorkingSetJSON;

public class XMIBasedTyphonQLClientTest {
	public static void main(String[] args) throws IOException, URISyntaxException {
		DatabaseInfo[] infos = new DatabaseInfo[] {
				new DatabaseInfo("localhost", 27017, "Reviews", DBType.documentdb, new MongoDB().getName(),
						"admin", "admin"),
				new DatabaseInfo("localhost", 3306, "Inventory", DBType.relationaldb, new MariaDB().getName(),
						"root", "example") };
		/*
		if (args == null || args.length != 1 && args[0] == null) {
			System.out.println("Provide XMI file name");
			System.exit(-1);
		}
		*/
			
		String fileName = "file:///Users/pablo/git/typhonql/typhonql/src/lang/typhonml/customdatatypes.xmi";
		
		String xmiString = String.join("\n", Files.readAllLines(Paths.get(new URI(fileName))));

		PolystoreConnection conn = new XMIPolystoreConnection(xmiString, Arrays.asList(infos));
		
		conn.resetDatabases();
		
		conn.executeUpdate("insert \n" + 
				"	@pablo User { name: \"Pablo\", reviews: badradio },\n" + 
				"	@radio Product {name: \"Radio\", description: \"Wireless\", reviews: badradio },\n" + 
				"	@badradio Review { contents: \"Bad radio\",product: radio,user: pablo}");
		
		//WorkingSet iv = conn.executeQuery("from Product p select p");
		WorkingSet iv = conn.executeQuery("from Product p select p");
		System.out.println("JSON");
		WorkingSetJSON.toJSON(iv, System.out);
		System.out.println("END JSON");
		
		System.out.println("JSON Schema");
		System.out.println(WorkingSetJSON.getSchema());
		System.out.println("END JSON Schema");
		
		String json = "{\"Product\":[{\"uuid\":\"48c5bfe5-04ab-4a62-9106-90d21007ee29\",\"fields\":{\"name\":\"Radio\",\"description\":\"Wireless\"},\"type\":\"Product\"}]}";
		
		WorkingSet ws = WorkingSetJSON.fromJSON(new ByteArrayInputStream(json.getBytes()));
		
		System.out.println("Parsed WS");
		System.out.println(ws);
		System.out.println("END parsed WS");
		
		

	}
}
