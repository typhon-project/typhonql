package engineering.swat.typhonql.client.test;

import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Arrays;

import nl.cwi.swat.typhonql.DBType;
import nl.cwi.swat.typhonql.MariaDB;
import nl.cwi.swat.typhonql.MongoDB;
import nl.cwi.swat.typhonql.client.CommandResult;
import nl.cwi.swat.typhonql.client.DatabaseInfo;
import nl.cwi.swat.typhonql.client.PolystoreConnection;
import nl.cwi.swat.typhonql.client.XMIPolystoreConnection;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;
import nl.cwi.swat.typhonql.workingset.json.WorkingSetJSON;

public class XMIBasedTyphonQLClientTest3PreparedStatements {
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
			
		String fileName = "file:///Users/pablo/git/typhonql/typhonql/src/lang/typhonml/user-review-product-bio.tmlx";
		
		String xmiString = String.join("\n", Files.readAllLines(Paths.get(new URI(fileName))));

		PolystoreConnection conn = new XMIPolystoreConnection(xmiString, Arrays.asList(infos));
		
		CommandResult[] crs = conn.executePreparedUpdate("insert \n" + 
				"	Product {name: ??name, description: ??description }", 
				new String[]{"description", "name"}, 
				new String[][]{ { "\"Best beer\"", "\"Omer\""}, { "\"Good IPA\"", "\"Jopen IPA\""}});
		
		for (CommandResult cr : crs) {
			for (String objLabel : cr.getCreatedUuids().keySet()) {
				System.out.println(objLabel + " -> " + cr.getCreatedUuids().get(objLabel));
			}
		}
		System.out.println("COMMAND RESULTS");
		for (CommandResult cr : crs)
			WorkingSetJSON.toJSON(cr, System.out);
		System.out.println("END COMMAND RESULTS");
		
		
		ResultTable iv = conn.executeQuery("from Product p select p.name");
		System.out.println("RESULT TABLE");
		iv.print();
		
	}
}
