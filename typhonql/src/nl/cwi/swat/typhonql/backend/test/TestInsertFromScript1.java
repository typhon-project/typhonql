package nl.cwi.swat.typhonql.backend.test;

import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.EntityModel;
import nl.cwi.swat.typhonql.backend.Field;
import nl.cwi.swat.typhonql.backend.GeneratedIdentifier;
import nl.cwi.swat.typhonql.backend.MariaDBEngine;
import nl.cwi.swat.typhonql.backend.MongoDBEngine;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.TyphonType;
import nl.cwi.swat.typhonql.workingset.Entity;
import nl.cwi.swat.typhonql.workingset.WorkingSet;

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

	public static void main(String[] args) {
		
		ResultStore store = new ResultStore();
		
		Map<String, String> uuids = new HashMap<String, String>();
		
		MariaDBEngine e1 = new MariaDBEngine(store, uuids, "localhost", 3306, "Inventory", "root", "example");
		
		uuids.put("param_0", UUID.randomUUID().toString());
		HashMap<String, Binding> map1 = new LinkedHashMap<String, Binding>();
		map1.put("param_0", new GeneratedIdentifier("param_0"));
		e1.executeUpdate("insert into `User` (`User.name`, `User.@id`) \nvalues (\'Tijs\', ${param_0});", map1);
		
	}
}
