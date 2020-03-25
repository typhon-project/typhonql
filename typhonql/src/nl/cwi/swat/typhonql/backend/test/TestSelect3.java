package nl.cwi.swat.typhonql.backend.test;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.Field;
import nl.cwi.swat.typhonql.backend.MariaDBEngine;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.TyphonType;
import nl.cwi.swat.typhonql.backend.rascal.Path;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;
import nl.cwi.swat.typhonql.workingset.Entity;

public class TestSelect3 {

	public static void main(String[] args) {
		/*
		ResultStore store = new ResultStore();
		
		Map<String, String> uuids = new HashMap<String, String>();
		List<Consumer<List<Record>>> script = new ArrayList<>();
		
		MariaDBEngine e1 = new MariaDBEngine(store, script, uuids, "localhost", 3306, "Inventory", "root", "example");
		
		e1.executeSelect("user", "select u.`User.name` as `u.User.name`,  u.`User.@id` as `u.User.@id` from User u where u.`User.name` = \"Victor\"");
		LinkedHashMap<String, Binding> map1 = new LinkedHashMap<String, Binding>();
		map1.put("user_id", new Field("user", "u", "User"));
		
		
		e1.executeSelect("user2", "select u.`User.name` as `u.User.name`,  u.`User.@id` as `u.User.@id` from User u where u.`User.@id` = ${user_id}",  map1);
		
		System.out.println("Final Result:");
		
		Map<String, TyphonType> attributes = new HashMap<>();
		
		attributes.put("name", TyphonType.STRING);
		
		ResultTable result = store.computeResultTable(script, Arrays.asList(new Path("Inventory", "u", "User", new String[] { "name" }) ));
		
		result.print();
		*/
		
	}
}
