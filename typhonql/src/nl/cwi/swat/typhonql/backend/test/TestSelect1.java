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

import java.sql.Connection;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Consumer;

import com.mongodb.client.MongoDatabase;

import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.Field;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.Runner;
import nl.cwi.swat.typhonql.backend.mariadb.MariaDBEngine;
import nl.cwi.swat.typhonql.backend.mongodb.MongoDBEngine;
import nl.cwi.swat.typhonql.backend.rascal.Path;
import nl.cwi.swat.typhonql.backend.rascal.TyphonSessionState;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

public class TestSelect1 {
	public static void main(String[] args) throws SQLException {
		
		ResultStore store = new ResultStore(Collections.emptyMap());
		
		Map<String, UUID> uuids = new HashMap<>();
		List<Consumer<List<Record>>> script = new ArrayList<>();
		List<Runnable> updates = new ArrayList<>();
		
		Connection conn1 = BackendTestCommon.getConnection("localhost", 3306, "Inventory", "root", "example");
		MongoDatabase conn2 = BackendTestCommon.getMongoDatabase("localhost", 27018, "Reviews", "admin", "admin");
		
		TyphonSessionState state = new TyphonSessionState();
		MariaDBEngine e1 = new MariaDBEngine(store, state, script, uuids, ()-> conn1);
		MongoDBEngine e2 = new MongoDBEngine(store, state, script, uuids, conn2);
		
		e1.executeSelect("Inventory", "select `junction_biography$0`.`Biography.user` as `u.User.biography`, `u`.`User.@id` as `u.User.@id` \nfrom `User` as `u` left outer join `Biography.user-User.biography` as `junction_biography$0` on (`junction_biography$0`.`User.biography`) = (`u`.`User.@id`)\nwhere true",
				Arrays.asList(new Path("Inventory", "u", "User", new String[] { "biography" })));
		LinkedHashMap<String, Binding> map1 = new LinkedHashMap<String, Binding>();
		map1.put("u_biography_0", new Field("Inventory", "u", "User", "biography"));
		e2.executeFind("Reviews","Biography","{\"_id\": ${u_biography_0}}" ,map1, Arrays.asList(new Path("Reviews", "b", "Biography", new String[] { "text" })));
		
		
		System.out.println("Final Result:");
		
		ResultTable result = Runner.computeResultTable(script,
				Arrays.asList(new Path("Reviews", "b", "Biography", new String[] { "text" }) ));
		
		System.out.println(result.toString());
		
	}
}
