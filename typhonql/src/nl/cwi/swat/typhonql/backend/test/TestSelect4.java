package nl.cwi.swat.typhonql.backend.test;

import java.sql.Connection;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.Runner;
import nl.cwi.swat.typhonql.backend.mariadb.MariaDBEngine;
import nl.cwi.swat.typhonql.backend.rascal.Path;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

public class TestSelect4 {

		
	public static void main(String[] args) throws SQLException {
		
		ResultStore store = new ResultStore();
		
		Map<String, String> uuids = new HashMap<String, String>();
		List<Consumer<List<Record>>> script = new ArrayList<>();
		List<Runnable> updates = new ArrayList<>();
		
		Connection conn1 = BackendTestCommon.getConnection("localhost", 3306, "Inventory", "root", "example");
		MariaDBEngine e1 = new MariaDBEngine(store, script, updates, uuids, conn1);
		
		e1.executeSelect("Inventory", "select `p`.`Product.name` as `p.Product.name`, `p`.`Product.@id` as `p.Product.@id` from `Product` as `p` where true;",
				Arrays.asList(new Path("Inventory", "p", "Product", new String[] { "name" })));
		ResultTable result = Runner.computeResultTable(script, Arrays.asList(new Path("Inventory", "p", "Product", new String[] { "name" }) ));
		
		System.out.println(result.toString());

		
	}
}
