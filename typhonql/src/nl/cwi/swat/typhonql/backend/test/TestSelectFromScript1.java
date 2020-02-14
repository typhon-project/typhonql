package nl.cwi.swat.typhonql.backend.test;

import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;

import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.EntityModel;
import nl.cwi.swat.typhonql.backend.MariaDBEngine;
import nl.cwi.swat.typhonql.backend.MongoDBEngine;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.TyphonType;
import nl.cwi.swat.typhonql.workingset.Entity;
import nl.cwi.swat.typhonql.workingset.WorkingSet;

public class TestSelectFromScript1 {
	
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

	public static void main(String[] args) {
		
		ResultStore store = new ResultStore();
		
		MariaDBEngine e1 = new MariaDBEngine(store, "localhost", 3306, "Inventory", "root", "example");
		MongoDBEngine e2 = new MongoDBEngine(store, "localhost", 27018, "Reviews", "admin", "admin");
		
		e1.executeSelect("Inventory", "select `u`.`User.@id` as `u.User.@id` \nfrom `User` as `u`\nwhere (`u`.`User.name`) = (\'Claudio\');");
		LinkedHashMap<String, Binding> map1 = new LinkedHashMap<String, Binding>();
		map1.put("u_@id_0", new Binding("Inventory", "u", "User", "@id"));
		e2.executeFindWithProjection("Reviews", "Review","{\"user\": ${u_@id_0}}", "{}", map1);
		
		System.out.println("Final Result:");
		
		Map<String, TyphonType> attributes = new HashMap<>();
		attributes.put("contents", TyphonType.STRING);
		WorkingSet result = store.computeResult("Reviews", new String[] { "review" }, new EntityModel("Review", attributes));
		
		for (Entity e : result.get("review")) {
			System.out.println(e);
		}

		
	}
}
