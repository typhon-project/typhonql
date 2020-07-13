package nl.cwi.swat.typhonql.backend.test;

import java.sql.Connection;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
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

public class TestFindManyAndUpdate {

	public static void main(String[] args) throws SQLException {
		ResultStore store = new ResultStore(Collections.emptyMap());
		
		Map<String, UUID> uuids = new HashMap<>();
		List<Consumer<List<Record>>> script = new ArrayList<>();
		List<Runnable> updates = new ArrayList<>();
		
		MongoDatabase conn1 = BackendTestCommon.getMongoDatabase("localhost", 27018, "Reviews", "admin", "admin");
		MongoDBEngine e1 = new MongoDBEngine(store, script, updates, uuids, conn1);
		
		Connection conn2 = BackendTestCommon.getConnection("localhost", 3306, "Inventory", "root", "example");
		MariaDBEngine e2 = new MariaDBEngine(store, script, updates, uuids, () -> conn2);
		
		Map<String, Binding> map = new HashMap<>();
		
		e2.executeSelect("Inventory", "select `p`.`Product.@id` as `p.Product.@id`, `p`.`Product.name` as `p.Product.name` from `Product` as `p`  where (`p`.`Product.name`) = (\\'Radio\\');;",
				Arrays.asList(new Path("Inventory", "p", "Product", new String[] { "@id" })));
		
		
		map.put("param_750", new Field("Inventory", "p", "Product", "@id"));
		e1.executeFindAndUpdateMany("Reviews","Review",
				"{}",
				"{\"$pull\": {\"product\": {\"$in\": [${param_750}]}}}",
				map);
		
		Runner.executeUpdates(script, updates);
	
	}
}
