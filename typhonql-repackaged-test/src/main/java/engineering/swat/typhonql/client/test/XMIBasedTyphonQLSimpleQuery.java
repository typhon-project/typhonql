package engineering.swat.typhonql.client.test;

import java.io.IOException;
import java.net.URISyntaxException;
import java.util.Collections;
import java.util.List;

import nl.cwi.swat.typhonql.client.CommandResult;
import nl.cwi.swat.typhonql.client.DatabaseInfo;
import nl.cwi.swat.typhonql.client.XMIPolystoreConnection;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

public class XMIBasedTyphonQLSimpleQuery {
	
	private static String HOST = "localhost";
	private static int PORT = 8080;
	private static String USER = "admin";
	private static String PASSWORD = "admin1@";
	
	public static void main(String[] args) throws IOException, URISyntaxException {
		
		
		List<DatabaseInfo> infos = PolystoreAPIHelper.readConnectionsInfo(HOST, PORT,
				USER, PASSWORD);
		
		String xmiString = PolystoreAPIHelper.readHttpModel(HOST, PORT, USER, PASSWORD);
		//System.err.println(xmiString);
		//System.err.println(infos);

		XMIPolystoreConnection conn = new XMIPolystoreConnection();
		
		//ResultTable rt = conn.executeQuery(xmiString, infos, "from Product p select p.name");
		//ResultTable rt = conn.executeQuery(xmiString, infos, "from Product p, Review r select r.content where p.reviews == r, p.@id == #tv");
		//CommandResult rt = conn.executeUpdate(xmiString, infos, Collections.emptyMap(), "update User u where u.@id == #davy set {photoURL: \"other\", name: \"Landman\"}");
		ResultTable rt = conn.executeQuery(xmiString, infos, "from User u select u.photoURL, u.name");

		System.out.println(rt);

	}
}
