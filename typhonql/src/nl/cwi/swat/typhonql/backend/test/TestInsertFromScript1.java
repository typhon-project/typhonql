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
import java.util.Optional;
import java.util.UUID;
import java.util.function.Consumer;

import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.GeneratedIdentifier;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.mariadb.MariaDBEngine;

public class TestInsertFromScript1 {
	
	/*
	 * script([
    step(
      "Inventory",
      sql(executeQuery("Inventory","select `u`.`User.@id` as `u.User.@id` \nfrom `User` as `u`\nwhere (`u`.`User.name`) = (\'Pablo\');")),
      ()),
    step(
      "Reviews",
      mongo(find("Reviews","{\"user\": ${u_@id_0}}","{}")),
      ("u_@id_0":<"Inventory","u","User","@id">))
  ])
	 */

	public static void main(String[] args) throws SQLException {
		
		ResultStore store = new ResultStore(Collections.emptyMap());
		
		Map<String, List<UUID>> uuids = new HashMap<>();
		
		List<Consumer<List<Record>>> script = new ArrayList<Consumer<List<Record>>>();
		List<Runnable> updates = new ArrayList<>();
		
		Connection conn = BackendTestCommon.getConnection("localhost", 3306, "Inventory", "root", "example");
		
		MariaDBEngine e1 = new MariaDBEngine(store, script, updates,uuids, () -> conn);
		
		uuids.put("param_0", Arrays.asList(UUID.randomUUID()));
		HashMap<String, Binding> map1 = new LinkedHashMap<String, Binding>();
		map1.put("param_0", new GeneratedIdentifier("param_0"));
		e1.executeUpdate("insert into `User` (`User.name`, `User.@id`) \nvalues (\'Tijs\', ${param_0});", map1, Optional.empty());
		
	}
}
