package nl.cwi.swat.typhonql.backend.test;

import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

import com.mongodb.client.MongoDatabase;

import nl.cwi.swat.typhonql.backend.MongoDBEngine;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.Runner;

public class TestDDLMongo {

		
	public static void main(String[] args) throws SQLException {
		ResultStore store = new ResultStore();
		
		Map<String, String> uuids = new HashMap<String, String>();
		List<Consumer<List<Record>>> script = new ArrayList<>();
		List<Runnable> updates = new ArrayList<>();
		
		MongoDatabase conn1 = BackendTestCommon.getMongoDatabase("localhost", 27018, "Reviews", "admin", "admin");
		
		MongoDBEngine e1 = new MongoDBEngine(store, script, updates, uuids, conn1);
		
		// script([step("Reviews",mongo(
		//	findAndUpdateMany("Reviews","Biography","","{$set: { \"rating\" : null}}")),()),finish()])
		e1.executeFindAndUpdateMany("Reviews","Biography",
				"",
				"{$set: { \"rating\" : null}}",
				Collections.EMPTY_MAP);

		Runner.executeUpdates(script, updates);
	}
}
