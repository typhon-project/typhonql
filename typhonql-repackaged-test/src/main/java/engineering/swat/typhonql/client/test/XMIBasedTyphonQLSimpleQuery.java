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
import java.util.UUID;

import nl.cwi.swat.typhonql.client.DatabaseInfo;
import nl.cwi.swat.typhonql.client.JsonSerializableResult;
import nl.cwi.swat.typhonql.client.XMIPolystoreConnection;

public class XMIBasedTyphonQLSimpleQuery {
	
	private static String HOST = "localhost";
	private static int PORT = 8080;
	private static String USER = "admin";
	private static String PASSWORD = "admin1@";
	
	public static void main(String[] args) throws IOException, URISyntaxException, InterruptedException {
		
		
		List<DatabaseInfo> infos = PolystoreAPIHelper.readConnectionsInfo(HOST, PORT,
				USER, PASSWORD);
		
		String xmiString = PolystoreAPIHelper.readHttpModel(HOST, PORT, USER, PASSWORD);
		//System.err.println(xmiString);
		System.err.println(infos);

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


		//conn.resetDatabases(xmiString, infos);

		//conn.executeUpdate(xmiString, infos, Collections.emptyMap(), "insert EntitySmokeTest2 { @id: #e1, s: \"Hoi\", t: \"Long\", i: 3, r: 12312312321, f: 20.001, b: true, d: $2020-01-02$, dt: $2020-03-04T12:04:44Z$, pt: #point(0.2 0.4), pg: #polygon((1.0 1.0, 4.0 1.0, 4.0 4.0, 1.0 4.0, 1.0 1.0)) }", true);
		/*
		conn.executePreparedUpdate(xmiString, infos, Collections.emptyMap(), "insert EntitySmokeTest2 { s: \"Hoi\", t: \"Long\", i: 3, r: 12312312321, f: 20.001, b: true, d: ??d, dt: ??dt, pt: #point(0.2 0.4), pg: #polygon((1.0 1.0, 4.0 1.0, 4.0 4.0, 1.0 4.0, 1.0 1.0)) }", 
				new String[] { "d", "dt" },
				new String[] { "date", "datetime" },
				new String[][] {
					new String[] { "2021-01-03", "2021-11-10T22:33:11Z"}
		}, true);
		*/
		JsonSerializableResult rt = conn.executeQuery(xmiString, infos, "from User u, Review r select r.@id, u.@id where distance(r.location, u.location) < 3000 && r.posted > $2020-01-01T00:00:00Z$", true);
		System.out.println(rt);
		rt.serializeJSON(System.out);
		System.exit(0);
		/*
		 * {
   "query": "insert RawTextWarnings {ew:??ew, timeStamp: $2020-12-01T12:12:14.567+00:00$}",
    "parameterNames":["ew"],
    "parameterTypes" : ["string"],
    "boundValues": [["Starkes Gewitter mit Starkregen (Stufe Orange) in Berlin eins twei drei"]]
}
		 */
	
		/*
		 * tity INSPIRE {
	id : int
    file_id: string[50]
    language: string[10]
    character_set: string[50]
    hierarchy_level: string[50]
    date_stamp: date
    metadata_standard_name: string[50]
    metadata_standard_version: string[50]
    rs_id: string[100]
    rs_code_space: string[100]
    spatial_resolution: int
		 */
		/*
		long start = System.currentTimeMillis();
		String[] res = conn.executePreparedUpdate(xmiString, infos, Collections.emptyMap(), "insert INSPIRE {"
				+ "file_id: ??f, language: ??l, character_set: ??c, hierarchy_level: ??h,"
				+ "date_stamp: ??d, metadata_standard_name: ??mn, metadata_standard_version: ??mv, "
				+ "rs_id: ??ri, rs_code_space: ??rs, spatial_resolution: ??sr}",
				new String[] { "f", "l", "c", "h", "d", "mn", "mv", "ri", "rs", "sr" },
				new String[] { "string", "string", "string", "string", "date", "string", "string", "string", "string", "int" },
				new String[][] { 
					new String[] { "file+ee", "nl-EN", "UTF-8", "ee1", "2020-11-22", "asdjhjksad", "23", "asdasdahsdhjkasd", "ass3", "340" },
			}
		, true);
		long stop = System.currentTimeMillis();
		System.out.println("First run: " + (stop - start));

		
		for (int i = 10; i <= 100000; i *= 10) {
			String[][] params = new String[i][];
			for (int j = 0; j < i; j++) {
				params[j] = new String[] { "file+ee" + i + "-" + j, "nl-EN", "UTF-8", "ee" + i, "2020-11-" + (i % 30), "asdjhjksad" + j, "" + j, "asdasdahsdhjkasd" + i, "ass3" +i, "" + (j+i) };
			}
			
            start = System.currentTimeMillis();
            conn.executePreparedUpdate(xmiString, infos, Collections.emptyMap(), "insert INSPIRE {"
				+ "file_id: ??f, language: ??l, character_set: ??c, hierarchy_level: ??h,"
				+ "date_stamp: ??d, metadata_standard_name: ??mn, metadata_standard_version: ??mv, "
				+ "rs_id: ??ri, rs_code_space: ??rs, spatial_resolution: ??sr}",
				new String[] { "f", "l", "c", "h", "d", "mn", "mv", "ri", "rs", "sr" },
				new String[] { "string", "string", "string", "string", "date", "string", "string", "string", "string", "int" },
                    params
            , false);
            stop = System.currentTimeMillis();
            long time = (stop - start);
            System.out.println(String.format("- Rows %-5d took: %-6dms speed: %-4.1f ms per record = %-4.1f records per second", i, time, time / (double)i, 1000 * (i / (double) time)));
		}
		*/

		/*
		entity GIPP_F {
			type: string[50]
			version: string[10]
			gipp_filename: string[100]
			mtd_msi -> MTD_MSI[1]
		}
		*/
		/*
		long start = System.currentTimeMillis();
		String[] res = conn.executePreparedUpdate(xmiString, infos, Collections.emptyMap(), "insert GIPP_F {"
				+ "type: ??t, version: ??v, gipp_filename: ??g, mtd_msi: ??i }",
				new String[] { "t", "v", "g", "i"},
				new String[] { "string", "string", "string", "uuid" },
				new String[][] { 
					new String[] { "tp", "vasasd2", "asdasd-sadasd-33-dd", UUID.randomUUID().toString() },
			}
		, true);
		long stop = System.currentTimeMillis();
		System.out.println("First run: " + (stop - start));

		
		for (int i = 10; i <= 100000; i *= 10) {
			String[][] params = new String[i][];
			for (int j = 0; j < i; j++) {
                params[j] = new String[] { "tp" + i + "-" + j, "vasasd2", "asdasd-sadasd-" + j + "-" + i, UUID.randomUUID().toString() };
			}
			
            start = System.currentTimeMillis();
            conn.executePreparedUpdate(xmiString, infos, Collections.emptyMap(), "insert GIPP_F {"
                    + "type: ??t, version: ??v, gipp_filename: ??g, mtd_msi: ??i }",
                    new String[] { "t", "v", "g", "i"},
                    new String[] { "string", "string", "string", "uuid" },
                    params
            , false);
            stop = System.currentTimeMillis();
            long time = (stop - start);
            System.out.println(String.format("- Rows %-5d took: %-6dms speed: %-4.1f ms per record = %-4.1f records per second", i, time, time / (double)i, 1000 * (i / (double) time)));
		}
		*/
		
		/*
		String[] res = conn.executePreparedUpdate(xmiString, infos, Collections.emptyMap(), "insert RawTextWarnings {ew:??ew, timeStamp: $2020-12-01T12:12:14.567+00:00$}",
				new String[] { "ew" },
				new String[] { "string" },
				new String[][] { new String[] { "Starkes Sonne mit Starkregen (Stufe Rote) in Berlin eins twei drei" }}
		, true);
		System.out.println(res);
		res = conn.executePreparedUpdate(xmiString, infos, Collections.emptyMap(), "insert RawTextWarnings {ew:??ew, timeStamp: $2020-12-01T12:12:14.567+00:00$}",
				new String[] { "ew" },
				new String[] { "string" },
				new String[][] { new String[] { "Starkes Sonne mit Starkregen (Stufe Rote) in Berlin eins twei drei" }}
		, true);
		System.out.println(res);
		Thread.sleep(5000);
		/*
		JsonSerializableResult rt = conn.executeQuery(xmiString, infos, "from RawTextWarnings u\n" + 
				"select u.@id, u.ew, u.ew.NamedEntityRecognition.WordToken\n" + 
				"where u.ew.NamedEntityRecognition.NamedEntity == \"WEATHER_EVENT\"", true);

		System.out.println(rt);
		rt.serializeJSON(System.out);
		*/

	}
}
