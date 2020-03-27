package engineering.swat.typhonql.client.test;

import java.io.IOException;
import java.net.URISyntaxException;
import java.util.List;

import nl.cwi.swat.typhonql.client.DatabaseInfo;
import nl.cwi.swat.typhonql.client.PolystoreConnection;
import nl.cwi.swat.typhonql.client.XMIPolystoreConnection;

public class XMIBasedTyphonQLResetDatabasesTest {
	
	private static String HOST = "localhost";
	private static int PORT = 8080;
	private static String USER = "pablo";
	private static String PASSWORD = "antonio";
	
	public static void main(String[] args) throws IOException, URISyntaxException {
		
		
		List<DatabaseInfo> infos = PolystoreAPIHelper.readConnectionsInfo(HOST, PORT,
				USER, PASSWORD);
		
		String xmiString = PolystoreAPIHelper.readHttpModel(HOST, PORT, USER, PASSWORD);

		PolystoreConnection conn = new XMIPolystoreConnection(xmiString, infos);
		
		conn.resetDatabases();
		
	}
}
