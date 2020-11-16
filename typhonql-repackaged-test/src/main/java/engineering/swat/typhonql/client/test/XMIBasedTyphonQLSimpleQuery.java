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
import nl.cwi.swat.typhonql.client.JsonSerializableResult;
import nl.cwi.swat.typhonql.client.XMIPolystoreConnection;

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
		
		//     p.runUpdate((Request) `insert ReferenceTest { @id: #r1, r: 2}`);
		//p.runUpdate((Request) `insert EntitySmokeTest { @id: #e1, s: "Hoi", t: "Long", i: 3, r: 12312312321, f: 20.001, b: true, d: $2020-01-02$, dt: $2020-03-04T12:04:44Z$, pt: #point(0.2 0.4), pg: #polygon((1.0 1.0, 4.0 1.0, 4.0 4.0, 1.0 4.0, 1.0 1.0)), ref: #r1 }`);
		//rs = p.runQuery((Request) `from EntitySmokeTest e select e.s, e.t, e.i, e.r, e.f, e.b, e.d, e.dt, e.pt, e.pg, e.ref where e.@id == #e1`);
		//p.assertResultEquals("Expected values working", rs, <
		//   ["e.s", "e.t", "e.i", "e.r", "e.f",  "e.b", "e.d", "e.dt", "e.pt", "e.pg", "e.ref"],
		//   [["Hoi", "Long", 3, 12312312321, 20.001, true, "2020-01-02", "2020-03-04T12:04:44Z", "POINT(0.2 0.4)", "POLYGON((1.0 1.0, 4.0 1.0, 4.0 4.0, 1.0 4.0, 1.0 1.0))", U("r1")]]>);

		//ResultTable rt = conn.executeQuery(xmiString, infos, "from Product p select p.name");
		//ResultTable rt = conn.executeQuery(xmiString, infos, "from Product p, Review r select r.content where p.reviews == r, p.@id == #tv");
		//CommandResult rt = conn.executeUpdate(xmiString, infos, Collections.emptyMap(), "update User u where u.@id == #davy set {photoURL: \"other\", name: \"Landman\"}");
		conn.resetDatabases(xmiString, infos);
		conn.executeUpdate(xmiString, infos, Collections.emptyMap(), "insert EntitySmokeTest2 { @id: #e1, s: \"Hoi\", t: \"Long\", i: 3, r: 12312312321, f: 20.001, b: true, d: $2020-01-02$, dt: $2020-03-04T12:04:44Z$, pt: #point(0.2 0.4), pg: #polygon((1.0 1.0, 4.0 1.0, 4.0 4.0, 1.0 4.0, 1.0 1.0)) }", true);
		JsonSerializableResult rt = conn.executeQuery(xmiString, infos, "from EntitySmokeTest2 e select e.s, e.t, e.i, e.r, e.f, e.b, e.d, e.dt, e.pt, e.pg", true);

		System.out.println(rt);
		rt.serializeJSON(System.out);

	}
}
