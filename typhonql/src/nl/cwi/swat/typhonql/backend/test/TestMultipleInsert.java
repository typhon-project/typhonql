package nl.cwi.swat.typhonql.backend.test;

import java.sql.Connection;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Consumer;

import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.Field;
import nl.cwi.swat.typhonql.backend.GeneratedIdentifier;
import nl.cwi.swat.typhonql.backend.MariaDBEngine;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.Runner;
import nl.cwi.swat.typhonql.backend.rascal.Path;

public class TestMultipleInsert {

	public static void main(String[] args) throws SQLException {
		
		//script([newId("param_611"),
		//    step("Inventory",sql(executeStatement("Inventory","insert into `Product` (`Product.name`, `Product.description`, `Product.@id`) \nvalues (\'IPhone\', \'Apple\', ${param_611});")),
		//       ("param_611":generatedId("param_611"))),finish()])
		//script([newId("param_612"),
		//       step("Inventory",sql(executeStatement("Inventory","insert into `Product` (`Product.name`, `Product.description`, `Product.@id`) \nvalues (\'Samsung S10\', \'Samsung\', ${param_612});")),
		//    		   ("param_612":generatedId("param_612"))),finish()])
		
		
		ResultStore store = new ResultStore();
		
		Map<String, String> uuids = new HashMap<String, String>();
		
		List<Consumer<List<Record>>> script = new ArrayList<>();
		List<Runnable> updates = new ArrayList<>();
		
		Connection conn1 = BackendTestCommon.getConnection("localhost", 3306, "Inventory", "root", "example");
		MariaDBEngine e1 = new MariaDBEngine(store, script, updates, uuids, conn1);
		LinkedHashMap<String, Binding> map0 = new LinkedHashMap<String, Binding>();
		String uuid = UUID.randomUUID().toString();
		uuids.put("param_611", uuid);
		map0.put("param_611", new GeneratedIdentifier("param_611"));
		e1.executeUpdate("insert into `Product` (`Product.name`, `Product.description`, `Product.@id`) \nvalues (\'IPhone\', \'Apple\', ${param_611});", map0);
		
		Runner.executeUpdates(script, updates);


		String uuid2 = UUID.randomUUID().toString();
		uuids.put("param_612", uuid2);
			
		LinkedHashMap<String, Binding> map1 = new LinkedHashMap<String, Binding>();
		map1.put("param_612", new GeneratedIdentifier("param_612"));
		
		e1.executeUpdate("insert into `Product` (`Product.name`, `Product.description`, `Product.@id`) \nvalues (\'Samsung S10\', \'Samsung\', ${param_612});", map1);		
		Runner.executeUpdates(script, updates);
		
		
	
		
	}
}
