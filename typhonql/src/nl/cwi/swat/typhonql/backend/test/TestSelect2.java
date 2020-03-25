package nl.cwi.swat.typhonql.backend.test;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.Field;
import nl.cwi.swat.typhonql.backend.MariaDBEngine;
import nl.cwi.swat.typhonql.backend.MongoDBEngine;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.rascal.Path;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

public class TestSelect2 {

	public static void main(String[] args) {
		ResultStore store = new ResultStore();
		
		Map<String, String> uuids = new HashMap<String, String>();
		List<Consumer<List<Record>>> script = new ArrayList<>();
		
		MariaDBEngine e1 = new MariaDBEngine(store, script, uuids, "localhost", 3306, "Inventory", "root", "example");
		MongoDBEngine e2 = new MongoDBEngine(store, script, uuids, "localhost", 27018, "Reviews", "admin", "admin");
		
		e2.executeFindWithProjection("Reviews","Review","{\"contents\": \"***\"}","{\"_id\": 1, \"user\": 1}",
				Collections.EMPTY_MAP, 
				Arrays.asList(new Path("Reviews", "r", "Review", new String[] { "user" })));
		
		LinkedHashMap<String, Binding> map1 = new LinkedHashMap<String, Binding>();
		map1.put("r_1", new Field("Reviews", "r", "Review", "@id"));
		
		e1.executeSelect("Inventory", 
				"select `u`.`User.name` as `u.User.name`, `u`.`User.@id` as `u.User.@id` \nfrom `User` as `u` left outer join `Review.user-User.reviews` as `junction_reviews$0` on (`junction_reviews$0`.`User.reviews`) = (`u`.`User.@id`)\nwhere (`junction_reviews$0`.`Review.user`) = (${r_1});",
				map1, Arrays.asList(new Path("Inventory", "u", "User", new String[] { "name" })));
		
		
		System.out.println("Final Result:");
		
		ResultTable result = store.computeResultTable(script,
				Arrays.asList(
						new Path("Inventory", "u", "User", new String[] { "name" }),
						new Path("Reviews", "r", "Review", new String[] { "user" }) ));
		
		result.print();
	}
}
