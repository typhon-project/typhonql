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

import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.Field;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.Runner;
import nl.cwi.swat.typhonql.backend.mariadb.MariaDBEngine;
import nl.cwi.swat.typhonql.backend.rascal.Path;
import nl.cwi.swat.typhonql.backend.rascal.TyphonSessionState;

public class TestDelete {

	public static void main(String[] args) throws SQLException {
		
		ResultStore store = new ResultStore(Collections.emptyMap());
		
		Map<String, UUID> uuids = new HashMap<>();
		
		List<Consumer<List<Record>>> script = new ArrayList<>();
		List<Runnable> updates = new ArrayList<>();
		
		Connection conn1 = BackendTestCommon.getConnection("localhost", 3306, "Inventory", "root", "example");
		MariaDBEngine e1 = new MariaDBEngine(store, new TyphonSessionState(), script, uuids, () -> conn1);
		
		e1.executeSelect("Inventory", "select `t`.`Tag.@id` as `t.Tag.@id` from `Tag` as `t` where true;", 
				Arrays.asList(new Path("Inventory", "t", "Tag", new String[] { "@id" })));
		
		LinkedHashMap<String, Binding> map1 = new LinkedHashMap<String, Binding>();
		map1.put("param_56", new Field("Inventory", "t", "Tag", "@id"));
		e1.executeUpdate("delete from `Tag` where (`Tag`.`Tag.@id`) = (${param_56});",map1);
		
		Runner.executeUpdates(script);
	
		
	}
}
