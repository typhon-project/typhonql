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

public class TestSelect2 {

	public static void main(String[] args) {
		
		ResultStore store = new ResultStore();
		
		MariaDBEngine e1 = new MariaDBEngine(store, "localhost", 3306, "Inventory", "root", "example");
		MongoDBEngine e2 = new MongoDBEngine(store, "localhost", 27018, "Reviews", "admin", "admin");
		
		e1.executeSelect("user", "select u.`User.@id` as `u.User.@id` from User u where u.`User.name` = \"Claudio\"");
		LinkedHashMap<String, Binding> map1 = new LinkedHashMap<String, Binding>();
		map1.put("user_id", new Binding("user", "u", "User"));
		e2.executeFind("review", "Review", "{ user: ${user_id} }", map1);
		
		// Binding needs an extra argument `attribute` for inspecting attributes in the entities that conform the stored results
		LinkedHashMap<String, Binding> map2 = new LinkedHashMap<String, Binding>();
		map2.put("product_id", new Binding("review", "dummy", "Review", "product"));
		
		e1.executeSelect("result", 
				"select p.`Product.@id` as `p.Product.@id`, p.`Product.name` as `p.Product.name`, p.`Product.description` as `p.Product.description` from Product p where p.`Product.@id` = ${product_id}", map2);
		
		
		//List<Entity> result = buildResult("result", );
		
		/*
		for (Entity e: store.getEntities("user")) {
			System.out.println(e);
		}
		
		for (Entity e: store.getEntities("review")) {
			System.out.println(e);
		}*/
		
		System.out.println("Final Result:");
		
		Map<String, TyphonType> attributes = new HashMap<>();
		attributes.put("description", TyphonType.STRING);
		attributes.put("name", TyphonType.STRING);
		WorkingSet result = store.computeResult("result", new String[] { "p" }, new EntityModel("Product", attributes));
		
		for (Entity e : result.get("p")) {
			System.out.println(e);
		}

		
	}
}
