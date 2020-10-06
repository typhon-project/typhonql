/********************************************************************************
* Copyright (c) 2018-2020 CWI & Swat.engineering 
*
* This program and the accompanying materials are made available under the
* terms of the Eclipse Public License 2.0 which is available at
* http://www.eclipse.org/legal/epl-2.0.
*
* This Source Code may also be made available under the following Secondary
* Licenses when the conditions for such availability set forth in the Eclipse
* Public License, v. 2.0 are satisfied: GNU General Public License, version 2
* with the GNU Classpath Exception which is
* available at https://www.gnu.org/software/classpath/license.html.
*
* SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0
********************************************************************************/

package engineering.swat.typhonql.client.test;

import java.io.IOException;
import java.net.URISyntaxException;
import java.util.Collections;
import java.util.List;

import nl.cwi.swat.typhonql.client.DatabaseInfo;
import nl.cwi.swat.typhonql.client.XMIPolystoreConnection;

public class XMIBasedTyphonQLDeleteTest {
	
	private static String HOST = "localhost";
	private static int PORT = 8080;
	private static String USER = "admin";
	private static String PASSWORD = "admin1@";
	
	public static void main(String[] args) throws IOException, URISyntaxException {
		
		
		List<DatabaseInfo> infos = PolystoreAPIHelper.readConnectionsInfo(HOST, PORT,
				USER, PASSWORD);
		
		String xmiString = PolystoreAPIHelper.readHttpModel(HOST, PORT, USER, PASSWORD);

		XMIPolystoreConnection conn = new XMIPolystoreConnection();
	
		List<DatabaseInfo> connections = PolystoreAPIHelper.readConnectionsInfo(HOST, PORT, USER, PASSWORD);
		
		//conn.resetDatabases(xmiString, connections);
		
		String query = "delete Product p where p.@id == #tv";
		conn.executeUpdate(xmiString, connections, Collections.EMPTY_MAP, query, true);
		
	}
}
