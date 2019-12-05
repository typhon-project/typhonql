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
import nl.cwi.swat.typhonql.client.DatabaseInfo;
import nl.cwi.swat.typhonql.client.PolystoreConnection;
import nl.cwi.swat.typhonql.client.XMIPolystoreConnection;
import nl.cwi.swat.typhonql.workingset.WorkingSet;


public class XMIBasedTyphonQLClientTest2 {
	public static void main(String[] args) throws IOException, URISyntaxException {
		DatabaseInfo[] infos = new DatabaseInfo[] {
				new DatabaseInfo("localhost", 27018, "MongoDB", DBType.documentdb, new MongoDB().getName(),
						"admin", "admin"),
				new DatabaseInfo("localhost", 3306, "MariaDBDWH", DBType.relationaldb, new MariaDB().getName(),
						"root", "example"),
				new DatabaseInfo("localhost", 3307, "MariaDBFinesse", DBType.relationaldb, new MariaDB().getName(),
						"root", "example")};
		
		String fileName = "file:///Users/pablo/git/typhonql/typhonql/src/lang/typhonml/alphabank.xmi";
		
		String xmiString = String.join("\n", Files.readAllLines(Paths.get(new URI(fileName))));

		PolystoreConnection conn = new XMIPolystoreConnection(xmiString, Arrays.asList(infos));
		conn.resetDatabases();
		
		/*
		WorkingSet iv = conn.executeQuery("from Product p select p");
		System.out.println(iv);
		
		iv = conn.executeQuery("from Product p select p");
		System.out.println(iv);*/
		
		conn.executeQuery("insert AC_Subscription{SubsId:156,SubType:3,Active:0,CompId:47390,ContPersId:798146,LangId:0,ApplicationProvId:1,ApplicationBranch : \"0107\", SignProvId:1,SignBranch : \"0107\", BasicProdId:433,PersonalCompName : \"\", PersonalCompTitle : \"\", DeactivatedTransId:0,AdministrationUnit : \"NULL\"}");
		

	}
}
