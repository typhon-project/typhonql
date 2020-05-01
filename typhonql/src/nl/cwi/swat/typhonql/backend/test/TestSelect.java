package nl.cwi.swat.typhonql.backend.test;

import java.sql.Connection;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

import com.mongodb.client.MongoDatabase;

import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.Field;
import nl.cwi.swat.typhonql.backend.MariaDBEngine;
import nl.cwi.swat.typhonql.backend.MongoDBEngine;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.Runner;
import nl.cwi.swat.typhonql.backend.rascal.Path;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

public class TestSelect {

	public static void main(String[] args) throws SQLException {
		
		ResultStore store = new ResultStore();
		
		Map<String, String> uuids = new HashMap<String, String>();
		
		List<Consumer<List<Record>>> script = new ArrayList<>();
		List<Runnable> updates = new ArrayList<>();
		
		Connection conn1 = BackendTestCommon.getConnection("localhost", 3306, "Inventory", "root", "example");
		MongoDatabase conn2 = BackendTestCommon.getMongoDatabase("localhost", 27018, "Reviews", "admin", "admin");
		MariaDBEngine e1 = new MariaDBEngine(store, script, updates, uuids, conn1);
		MongoDBEngine e2 = new MongoDBEngine(store, script, updates, uuids, conn2);
		
		e1.executeSelect("Inventory", "select u.`User.name` as `u.User.name`,  u.`User.@id` as `u.User.@id` from User u where u.`User.name` = \"Claudio\"", 
				Arrays.asList(new Path("Inventory", "u", "User", new String[] { "@id" })));
		LinkedHashMap<String, Binding> map1 = new LinkedHashMap<String, Binding>();
		map1.put("user_id", new Field("user", "u", "User"));
		e2.executeFind("review", "Review", "{ user: ${user_id} }", map1,
				Arrays.asList(new Path("Reviews", "r", "Review", new String[] { "product" })));
		
		// Binding needs an extra argument `attribute` for inspecting attributes in the entities that conform the stored results
		LinkedHashMap<String, Binding> map2 = new LinkedHashMap<String, Binding>();
		map2.put("product_id", new Field("review", "r", "Review", "product"));
		
		e1.executeSelect("result", 
				"select p.`Product.@id` as `p.Product.@id`, p.`Product.name` as `p.Product.name`, p.`Product.description` as `p.Product.description` from Product p where p.`Product.@id` = ${product_id}",
				Arrays.asList(new Path("Inventory", "p", "Product", new String[] { "name" })));
		
	
		System.out.println("Final Result:");
		
		ResultTable result = Runner.computeResultTable(script,
				Arrays.asList(new Path("Inventory", "p", "Product", new String[] { "name" }) ));
		
		result.print();

		
	}
}
