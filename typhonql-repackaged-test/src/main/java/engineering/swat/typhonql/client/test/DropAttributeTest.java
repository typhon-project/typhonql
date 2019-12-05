package engineering.swat.typhonql.client.test;

import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Arrays;

import io.usethesource.vallang.IMapWriter;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.impl.persistent.ValueFactory;
import nl.cwi.swat.typhonql.Bridge;
import nl.cwi.swat.typhonql.DBType;
import nl.cwi.swat.typhonql.MariaDB;
import nl.cwi.swat.typhonql.MongoDB;
import nl.cwi.swat.typhonql.client.DatabaseInfo;
import nl.cwi.swat.typhonql.client.PolystoreConnection;
import nl.cwi.swat.typhonql.client.XMIPolystoreConnection;

public class DropAttributeTest {

	public static void main(String[] args) throws IOException, URISyntaxException {
		DatabaseInfo[] infos = new DatabaseInfo[] {
				new DatabaseInfo("localhost", 27017, "Reviews", DBType.documentdb, new MongoDB().getName(),
						"admin", "admin"),
				new DatabaseInfo("localhost", 3306, "Inventory", DBType.relationaldb, new MariaDB().getName(),
						"root", "example") };
		
		String fileName = "file:///Users/pablo/git/typhonql/typhonql/src/lang/typhonml/customdatatypes.xmi";
		
		String xmiString = String.join("\n", Files.readAllLines(Paths.get(new URI(fileName))));

		PolystoreConnection conn = new XMIPolystoreConnection(xmiString, Arrays.asList(infos));
		
		conn.resetDatabases();
		
		
		/*conn.executeUpdate("insert \n" + 
				"	@pablo User { name: \"Pablo\", reviews: badradio },\n" + 
				"	@radio Product {name: \"Radio\", description: \"Wireless\", reviews: badradio },\n" + 
				"	@badradio Review { contents: \"Bad radio\",product: radio,user: pablo}");
		
		conn.executeUpdate("drop attribute User.name");*/
		
	}
	
}
