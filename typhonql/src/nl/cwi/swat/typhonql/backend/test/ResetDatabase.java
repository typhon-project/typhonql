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
				new DatabaseInfo("localhost", 27017, "Reviews", "mongodb", "",
						"admin", "admin"),
				new DatabaseInfo("localhost", 3306, "Inventory", "mariadb", "",
						"root", "example") };
		
		String fileName = "file:///Users/pablo/git/typhonql/typhonql/src/lang/typhonql/test/resources/user-review-product/user-review-product.xmi";
		
		String xmiString = String.join("\n", Files.readAllLines(Paths.get(new URI(fileName))));

		XMIPolystoreConnection conn = new XMIPolystoreConnection();
		
		conn.resetDatabases(xmiString, Arrays.asList(infos));
		
	}
	
}
