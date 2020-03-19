package nl.cwi.swat.typhonql.backend.test;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.EntityModel;
import nl.cwi.swat.typhonql.backend.Field;
import nl.cwi.swat.typhonql.backend.MariaDBEngine;
import nl.cwi.swat.typhonql.backend.MongoDBEngine;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.TyphonType;
import nl.cwi.swat.typhonql.backend.rascal.Path;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;
import nl.cwi.swat.typhonql.workingset.Entity;
import nl.cwi.swat.typhonql.workingset.WorkingSet;

public class TestSelect1 {
	public static void main(String[] args) {
		
		ResultStore store = new ResultStore();
		
		Map<String, String> uuids = new HashMap<String, String>();
		List<Consumer<List<Record>>> script = new ArrayList<>();
		
		MariaDBEngine e1 = new MariaDBEngine(store, script, uuids, "localhost", 3306, "Inventory", "root", "example");
		MongoDBEngine e2 = new MongoDBEngine(store, script, uuids, "localhost", 27018, "Reviews", "admin", "admin");
		
		e1.executeSelect("Inventory", "select `junction_biography$0`.`Biography.user` as `u.User.biography`, `u`.`User.@id` as `u.User.@id` \nfrom `User` as `u` left outer join `Biography.user-User.biography` as `junction_biography$0` on (`junction_biography$0`.`User.biography`) = (`u`.`User.@id`)\nwhere true",
				Arrays.asList(new Path("Inventory", "u", "User", new String[] { "biography" })));
		LinkedHashMap<String, Binding> map1 = new LinkedHashMap<String, Binding>();
		map1.put("u_biography_0", new Field("Inventory", "u", "User", "biography"));
		e2.executeFind("Reviews","Biography","{\"_id\": ${u_biography_0}}" ,map1, Arrays.asList(new Path("Reviews", "b", "Biography", new String[] { "text" })));
		
		
		System.out.println("Final Result:");
		
		ResultTable result = store.computeResultTable(script,
				Arrays.asList(new Path("Reviews", "b", "Biography", new String[] { "text" }) ));
		
		result.print();

		
	}
}
