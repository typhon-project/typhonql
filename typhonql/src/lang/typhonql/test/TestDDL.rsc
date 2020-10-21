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

module lang::typhonql::\test::TestDDL

import lang::typhonql::util::Log;

import IO;

import lang::typhonml::TyphonML;

import lang::typhonql::util::Testing;
import lang::typhonml::Util;
import lang::typhonql::TDBC;
import lang::typhonql::Normalize; // for pUUID

/*
 * These tests are meant to be run on a Typhon Polystore deployed according to the
 * resources/user-reviews-product folder
 */
 
str U(str u) = pUUID(u);
str base64(str b) = base64Encode(b);
 
str HOST = "localhost";
str PORT = "8080";
str USER = "admin";
str PASSWORD = "admin1@";

public Log PRINT() = void(value v) { println("LOG: <v>"); };


void setup(PolystoreInstance p, bool _) {
}

// DDL
 
void testCreateEntityMariaDB(PolystoreInstance p) {
	 s = p.fetchSchema();
	 
	 // We need to fake the schema update//
	 s.entities += { "CreditCard" };
	 s.placement += { << sql(), "Inventory" >,  "CreditCard"> };
	
     p.runDDL((Request) `create CreditCard at Inventory`);
	 
	 rs = p.runQueryForSchema((Request) `from CreditCard c select c.@id`, s);
	 p.assertEquals("create entity works on MariaDB", rs,  <["c.@id"],[]>);
	 
}

void testCreateEntityMongo(PolystoreInstance p) {
	 s = p.fetchSchema();
	 
	 // We need to fake the schema update
	 //s.rels += { <"User", zero_one(), "foo", "bar", zero_one(), "Comment", false> };
	 s.entities += { "Comment" };
	 s.placement += { << mongodb(), "Reviews" >,  "Comment"> };
	 p.runDDL((Request) `create Comment at Reviews`);
	 rs = p.runQueryForSchema((Request) `from Comment c select c.@id`, s);
	 p.assertEquals("create entity works on Mongo", rs,  <["c.@id"],[]>);
	 
}

void testCreateEntityNeo(PolystoreInstance p) {
	 s = p.fetchSchema();
	 s.entities += { "Friend" };
	 s.placement += { << neo4j(), "MoreStuff" >,  "Friend"> };
	 p.runUpdate((Request) `create Friend at MoreStuff`);
	 
}

void testDropEntityMariaDB(PolystoreInstance p) {
	 s = p.fetchSchema();
	 p.runUpdate((Request) `drop Product`);
	 s.rels -= { p | p:<"Product", _, _, _, _, _, _> <- s.rels };
	 s.attrs -= { p | p:<"Product", _, _> <- s.attrs };
	 p.assertException("drop entity works on MariaDB",
	 	void() { p.runQuery((Request) `from Product p select p`);});
	 
}


void testDropEntityMongo(PolystoreInstance p) {
	 s = p.fetchSchema();
	 
	 p.runUpdate((Request) `drop Biography`);
	  // We need to fake the schema update
	 s.rels -= { p | p:<"Biography", _, _, _, _, _, _> <- s.rels };
	 s.attrs -= { p | p:<"Biography", _, _> <- s.attrs };
	 
	 p.assertException("drop entity works on Mongo",
	 	void() { p.runQueryForSchema((Request) `from Biography b select b`, s);});
	 
}

void testDropEntityNeo(PolystoreInstance p) {
	 s = p.fetchSchema();
	 
	 p.runUpdate((Request) `drop Wish`);
	  // We need to fake the schema update
	 s.rels -= { p | p:<"Wish", _, _, _, _, _, _> <- s.rels };
	 s.rels -= { p | p:<_, _, _, _, _, "Wish", _> <- s.rels };
	 s.attrs -= { p | p:<"Wish", _, _> <- s.attrs };
	 
	 p.assertException("drop entity works on Neo",
	 	void() { p.runQueryForSchema((Request) `from Wish w select w`, s);});
	 
}

void testCreateAttributeMariaDB(PolystoreInstance p) {
	 s = p.fetchSchema();
	 
	 // We need to fake the schema update
	 s.attrs += { <"Product", "availability", "int">};
	 p.runDDL((Request) `create Product.availability : int`);
	 p.runUpdateForSchema((Request) `insert Product {@id: #guitar, name: "Guitar", description: "Wood", availability: 50 }`, s);
	 rs = p.runQueryForSchema((Request) `from Product p select p.@id, p.availability`, s);
	 p.assertEquals("create attribute works on MariaDB", rs,  <["p.@id", "p.availability"],[[ U("guitar"), 50 ]]>);
}

void testCreateAttributeMongo(PolystoreInstance p) {
	 s = p.fetchSchema();
	 
	 // We need to fake the schema update
	 s.attrs += { <"Biography", "country", "string(256)">};
	 p.runDDL((Request) `create Biography.rating : int`);
	 p.runUpdateForSchema((Request) `insert Biography {@id: #bio1, content: "Good guy", country: "CL" }`, s);
	 rs = p.runQueryForSchema((Request) `from Biography b select b.@id, b.country`, s);
	 p.assertEquals("create attribute works on Mongo", rs,  <["b.@id", "b.country"],[[ U("bio1"), "CL" ]]>);
}

void testCreateAttributeNeo(PolystoreInstance p) {
	 s = p.fetchSchema();
	 p.runUpdate((Request) `insert Product {@id: #tv, name: "TV", description: "Flat", productionDate:  $2020-04-13$, availabilityRegion: #polygon((1.0 1.0, 4.0 1.0, 4.0 4.0, 1.0 4.0, 1.0 1.0)), price: 20 }`);
	 p.runUpdate((Request) `insert User { @id: #pablo, name: "Pablo", location: #point(2.0 3.0), 
                          '  created: $2020-01-02T12:24:00$,
	                      '   photoURL: "moustache",
	                      '   avatarURL: "blocky",
	                      '   address: "alsoThere",
	                      '   billing: address( street: "Seventh", city: "Ams"
	                      '   , zipcode: zip(nums: "1234", letters: "ab")
	                      '   , location: #point(2.0 3.0))}`);
     p.runUpdate((Request) `insert User { @id: #davy, name: "Davy", location: #point(20.0 30.0), photoURL: "beard",
                          '  created: $2020-01-02T12:24:00-03:00$,
	                      '   avatarURL: "blockyBeard",
	                      '   address: "alsoThere",
	                      '  billing: address( street: "Bla", city: "Almere"
	                      '   , zipcode: zip(nums: "4566", letters: "cd")
	                      '   , location: #point(20.0 30.0))}`);	                      
	 
	 p.runUpdate((Request) `insert Wish { @id: #wish1, intensity: 7, user: #pablo, product: #tv }`);
	 
	 // We need to fake the schema update
	 s.attrs += { <"Wish", "description", "string(256)">};
	 p.runDDL((Request) `create Wish.description : string(256)`);
	 
	 p.runUpdateForSchema((Request) `insert Wish {@id: #wish3, product: #tv, user: #davy, intensity: 2, description: "For a long time" }`, s);
	 
	
	 rs = p.runQueryForSchema((Request) `from Wish w select w.@id, w.intensity, w.description where w.@id == #wish3`, s);
	 p.assertEquals("create attribute works on Neo 1", rs, <["w.@id", "w.intensity", "w.description"],[[ U("wish3"), 2, "For a long time"]]>);
	 rs = p.runQueryForSchema((Request) `from Wish w select w.@id, w.intensity, w.description where w.@id == #wish1`, s);
	 p.assertEquals("create attribute works on Neo 2", rs,  <["w.@id", "w.intensity", "w.description"],[[ U("wish1"), 7, {}]]>);
	 
	 
}

void testDropAttributeMariaDB(PolystoreInstance p) {
	 s = p.fetchSchema();
	 p.runDDL((Request) `drop attribute Product.description`);
	 
	 // We need to fake the schema update
	 s.attrs -=  {<"Product", "description", "string(256)">};
	 p.assertException("drop attribute works on MariaDB",
	 	void() { p.runQuery((Request) `from Product p select p.description`);});
}

// drop attribute (document)
void testDropAttributeMongo(PolystoreInstance p) {
	 s = p.fetchSchema();
	 p.runDDL((Request) `drop attribute Review.content`);
	 
	 // We need to fake the schema update
	 s.attrs -= {<"Review", "content", "text">};
	 p.assertException("drop attribute works on Mongo",
	 	void() { rt = p.runQuery((Request) `from Review r select r.content`); });
}

// drop attribute (neo)
void testDropAttributeNeo(PolystoreInstance p) {
	 p.runUpdate((Request) `insert Product {@id: #tv, name: "TV", description: "Flat", productionDate:  $2020-04-13$, availabilityRegion: #polygon((1.0 1.0, 4.0 1.0, 4.0 4.0, 1.0 4.0, 1.0 1.0)), price: 20 }`);
	 p.runUpdate((Request) `insert User { @id: #pablo, name: "Pablo", location: #point(2.0 3.0), 
                          '  created: $2020-01-02T12:24:00$,
	                      '   photoURL: "moustache",
	                      '   avatarURL: "blocky",
	                      '   address: "alsoThere",
	                      '   billing: address( street: "Seventh", city: "Ams"
	                      '   , zipcode: zip(nums: "1234", letters: "ab")
	                      '   , location: #point(2.0 3.0))}`);
     p.runUpdate((Request) `insert User { @id: #davy, name: "Davy", location: #point(20.0 30.0), photoURL: "beard",
                          '  created: $2020-01-02T12:24:00-03:00$,
	                      '   avatarURL: "blockyBeard",
	                      '   address: "alsoThere",
	                      '  billing: address( street: "Bla", city: "Almere"
	                      '   , zipcode: zip(nums: "4566", letters: "cd")
	                      '   , location: #point(20.0 30.0))}`);	                      
	 
	 p.runUpdate((Request) `insert Wish { @id: #wish1, intensity: 7, user: #pablo, product: #tv }`);
	 s = p.fetchSchema();
	 p.runDDL((Request) `drop attribute Wish.intensity`);
	 
	 // We need to fake the schema update
	 s.attrs -= {<"Wish", "intensity", "int">};
	 p.assertException("drop attribute works on Neo",
	 	void() { rt = p.runQuery((Request) `from Wish w select w.intensity`); });
}


void testCreateRelationMariaDB(PolystoreInstance p) {
	 Schema s = p.fetchSchema();
	 
	 // We need to fake the schema update
	 s.rels += { <"User", zero_many(), "products", "products^", \one(), "Product", false>};
	 p.runDDL((Request) `create User.products -\> Product[0..*]`);
	 //p.runUpdateForSchema((Request) `insert Product {@id: #guitar, name: "Guitar", description: "Wood", availability: 50 }`, s);
	 //rs = p.runQueryForSchema((Request) `from Product p select p.@id, p.availability`, s);
	 //p.assertEquals("test5", rs,  <["p.@id", "p.availability"],[[ "guitar", 50 ]]>);
}

void testDropRelationMariaDB(PolystoreInstance p) {
	 Schema s = p.fetchSchema();
	 
	 // We need to fake the schema update
	 s.rels += { <"User", zero_many(), "products", "products^", \one(), "Product", false>};
	 p.runDDLForSchema((Request) `drop relation User.products`, s);
	 //p.runUpdateForSchema((Request) `insert Product {@id: #guitar, name: "Guitar", description: "Wood", availability: 50 }`, s);
	 //rs = p.runQueryForSchema((Request) `from Product p select p.@id, p.availability`, s);
	 //p.assertEquals("test5", rs,  <["p.@id", "p.availability"],[[ "guitar", 50 ]]>);
}


TestExecuter executer(Log log = NO_LOG()) = 
	initTest(setup, HOST, PORT, USER, PASSWORD, log = log, doTypeChecking = false);
	
void runTest(void(PolystoreInstance) t, Log log = NO_LOG(), bool runSetup = true) {
	executer(log = log).runTest(t, runSetup, false); 
}

void runTests(list[void(PolystoreInstance)] ts, Log log = NO_LOG()) {
	executer(log = log).runTests(ts, false, log = log); 
}

void runAll() {
	runTests([
		testCreateEntityMariaDB,
		testCreateEntityMongo,
		//testDropEntityMariaDB,
		testDropEntityMongo,
		//testCreateAttributeMariaDB,
		testCreateAttributeMongo,
		testDropAttributeMariaDB,
		testDropAttributeMongo,
		testCreateRelationMariaDB,
		testDropRelationMariaDB
		]);
}
