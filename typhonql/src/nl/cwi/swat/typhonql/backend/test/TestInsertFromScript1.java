package nl.cwi.swat.typhonql.backend.test;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Consumer;

import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.GeneratedIdentifier;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.mariadb.MariaDBEngine;

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

	public static void main(String[] args) throws SQLException {
		
		ResultStore store = new ResultStore();
		
		Map<String, String> uuids = new HashMap<String, String>();
		
		List<Consumer<List<Record>>> script = new ArrayList<Consumer<List<Record>>>();
		List<Runnable> updates = new ArrayList<>();
		
		Connection conn = BackendTestCommon.getConnection("localhost", 3306, "Inventory", "root", "example");
		
		MariaDBEngine e1 = new MariaDBEngine(store, script, updates,uuids, () -> conn);
		
		uuids.put("param_0", UUID.randomUUID().toString());
		HashMap<String, Binding> map1 = new LinkedHashMap<String, Binding>();
		map1.put("param_0", new GeneratedIdentifier("param_0"));
		e1.executeUpdate("insert into `User` (`User.name`, `User.@id`) \nvalues (\'Tijs\', ${param_0});", map1);
		
	}
}
