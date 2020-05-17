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
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

public class TestSelect2 {

	public static void main(String[] args) throws SQLException {
		ResultStore store = new ResultStore();
		
		Map<String, String> uuids = new HashMap<String, String>();
		List<Consumer<List<Record>>> script = new ArrayList<>();
		List<Runnable> updates = new ArrayList<>();
		
		Connection conn1 = BackendTestCommon.getConnection("localhost", 3306, "Inventory", "root", "example");
		MongoDatabase conn2 = BackendTestCommon.getMongoDatabase("localhost", 27018, "Reviews", "admin", "admin");
		
		MariaDBEngine e1 = new MariaDBEngine(store, script, updates, uuids, conn1);
		MongoDBEngine e2 = new MongoDBEngine(store, script, updates, uuids, conn2);
		
		e2.executeFindWithProjection("Reviews","Review","{\"contents\": \"***\"}","{\"_id\": 1, \"user\": 1}",
				Collections.EMPTY_MAP, 
				Arrays.asList(new Path("Reviews", "r", "Review", new String[] { "user" })));
		
		LinkedHashMap<String, Binding> map1 = new LinkedHashMap<String, Binding>();
		map1.put("r_1", new Field("Reviews", "r", "Review", "@id"));
		
		e1.executeSelect("Inventory", 
				"select `u`.`User.name` as `u.User.name`, `u`.`User.@id` as `u.User.@id` \nfrom `User` as `u` left outer join `Review.user-User.reviews` as `junction_reviews$0` on (`junction_reviews$0`.`User.reviews`) = (`u`.`User.@id`)\nwhere (`junction_reviews$0`.`Review.user`) = (${r_1});",
				map1, Arrays.asList(new Path("Inventory", "u", "User", new String[] { "name" })));
		
		
		System.out.println("Final Result:");
		
		ResultTable result = Runner.computeResultTable(script,
				Arrays.asList(
						new Path("Inventory", "u", "User", new String[] { "name" }),
						new Path("Reviews", "r", "Review", new String[] { "user" }) ));
		
		System.out.println(result.toString());
	}
}
