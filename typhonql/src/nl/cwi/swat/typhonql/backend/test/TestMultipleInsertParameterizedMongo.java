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

import com.mongodb.client.MongoDatabase;

import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.Field;
import nl.cwi.swat.typhonql.backend.GeneratedIdentifier;
import nl.cwi.swat.typhonql.backend.MultipleBindings;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.Runner;
import nl.cwi.swat.typhonql.backend.mariadb.MariaDBEngine;
import nl.cwi.swat.typhonql.backend.mongodb.MongoDBEngine;
import nl.cwi.swat.typhonql.backend.rascal.Path;

public class TestMultipleInsertParameterizedMongo{

	public static void main(String[] args) {
		
		//script([newId("param_611"),
		//    step("Inventory",sql(executeStatement("Inventory","insert into `Product` (`Product.name`, `Product.description`, `Product.@id`) \nvalues (\'IPhone\', \'Apple\', ${param_611});")),
		//       ("param_611":generatedId("param_611"))),finish()])
		//script([newId("param_612"),
		//       step("Inventory",sql(executeStatement("Inventory","insert into `Product` (`Product.name`, `Product.description`, `Product.@id`) \nvalues (\'Samsung S10\', \'Samsung\', ${param_612});")),
		//    		   ("param_612":generatedId("param_612"))),finish()])
		
		
		ResultStore store = new ResultStore(Collections.emptyMap());
		
		Map<String, List<UUID>> uuids = new HashMap<>();
		
		List<Consumer<List<Record>>> script = new ArrayList<>();
		List<Runnable> updates = new ArrayList<>();
		
		MongoDatabase conn1 = BackendTestCommon.getMongoDatabase("localhost", 27018, "Reviews", "admin", "admin");
		MongoDBEngine e1 = new MongoDBEngine(store, script, updates, uuids, conn1);
		LinkedHashMap<String, Binding> map0 = new LinkedHashMap<String, Binding>();
		List<UUID> lst1 = new ArrayList<UUID>();
		lst1.add(UUID.randomUUID());
		lst1.add(UUID.randomUUID());
		uuids.put("param_611", lst1);
		map0.put("param_611", new GeneratedIdentifier("param_611"));
		MultipleBindings mbs = new MultipleBindings(Arrays.asList("content", "user", "product"),
				Arrays.asList("string"), 
				Arrays.asList(Arrays.asList("Excellent TV"),
							  Arrays.asList("Awful TV")));
				
		e1.executeInsertOne("Reviews", "Review", "{\"content\": ${content}, \"location\": {\"type\": \"Point\", \"coordinates\": [2.0, 3.0]}, \"_id\": ${param_59}}", 
				map0, Optional.of(mbs));
		
		Runner.executeUpdates(script, updates);


		/*UUID uuid2 = UUID.randomUUID();
		List<UUID> lst2 = new ArrayList<UUID>();
		lst2.add(uuid2);
		uuids.put("param_612",lst2);
			
		LinkedHashMap<String, Binding> map1 = new LinkedHashMap<String, Binding>();
		map1.put("param_612", new GeneratedIdentifier("param_612"));
		
		e1.executeUpdate("insert into `Product` (`Product.name`, `Product.description`, `Product.@id`) \nvalues (\'Samsung S10\', \'Samsung\', ${param_612});", map1, Optional.empty());		
		Runner.executeUpdates(script, updates);*/
		
		
	
		
	}
}
