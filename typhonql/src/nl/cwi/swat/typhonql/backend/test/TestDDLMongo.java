/********************************************************************************
* Copyright (c) 2018-2020 CWI & Swat.engineering 
*
* This program and the accompanying materials are made available under the
* terms of the Eclipse Public License 2.0 which is available at
* http://www.eclipse.org/legal/epl-2.0.
*
* This Source Code may also be made available under the following Secondary
* Licenses when the conditions for such availability set forth in the Eclipse
* Public License, v. 2.0 are satisfied: GNU General Public License, version 2
* with the GNU Classpath Exception which is
* available at https://www.gnu.org/software/classpath/license.html.
*
* SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0
********************************************************************************/

package nl.cwi.swat.typhonql.backend.test;

import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Consumer;

import com.mongodb.client.MongoDatabase;

import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.Runner;
import nl.cwi.swat.typhonql.backend.mongodb.MongoDBEngine;
import nl.cwi.swat.typhonql.backend.rascal.TyphonSessionState;

public class TestDDLMongo {

		
	public static void main(String[] args) throws SQLException {
		ResultStore store = new ResultStore(Collections.emptyMap());
		
		Map<String, UUID> uuids = new HashMap<>();
		List<Consumer<List<Record>>> script = new ArrayList<>();
		List<Runnable> updates = new ArrayList<>();
		
		MongoDatabase conn1 = BackendTestCommon.getMongoDatabase("localhost", 27018, "Reviews", "admin", "admin");
		
		MongoDBEngine e1 = new MongoDBEngine(store, new TyphonSessionState(), script, uuids, conn1);
		
		// script([step("Reviews",mongo(
		//	findAndUpdateMany("Reviews","Biography","","{$set: { \"rating\" : null}}")),()),finish()])
		e1.executeFindAndUpdateMany("Reviews","Biography",
				"",
				"{$set: { \"rating\" : null}}",
				Collections.EMPTY_MAP);

		Runner.executeUpdates(script);
	}
}
