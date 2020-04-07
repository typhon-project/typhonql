module lang::typhonql::\test::TestDDL

import lang::typhonql::util::Log;

import IO;

extend lang::typhonql::util::Testing;

/*
 * These tests are meant to be run on a Typhon Polystore deployed according to the
 * resources/user-reviews-product folder
 */
 
 
str HOST = "localhost";
str PORT = "8080";
str USER = "admin";
str PASSWORD = "admin1@";
Log LOG = NO_LOG;


void setup() {
	runUpdate((Request) `insert User { @id: #pablo, name: "Pablo" }`);
	runUpdate((Request) `insert User { @id: #davy, name: "Davy" }`);
	
	runUpdate((Request) `insert Product {@id: #tv, name: "TV", description: "Flat" }`);
	runUpdate((Request) `insert Product {@id: #radio, name: "Radio", description: "Loud" }`);
	
	runUpdate((Request) `insert Review { @id: #rev1, contents: "Good TV", user: #pablo, product: #tv }`);
	runUpdate((Request) `insert Review { @id: #rev2, contents: "", user: #davy, product: #tv }`);
	runUpdate((Request) `insert Review { @id: #rev3, contents: "***", user: #davy, product: #radio }`);
	
	runUpdate((Request) `insert Biography { @id: #bio1, text: "Chilean", user: #pablo }`);
}

// DDL

void test1() {
	 s = fetchSchema();
	 
	 // We need to fake the schema update
	 s.rels += { <"CreditCard", zero_one(), "foo", "bar", zero_one(), "User", false> };
	 s.placement += { << sql(), "Inventory" >,  "CreditCard"> };
	
     runDDL((Request) `create CreditCard at Inventory`);
	 
	 rs = runQuery((Request) `from CreditCard c select c`, s);
	 assertEquals("test15", rs,  <["c.@id"],[]>);
	 
}

void test2() {
	 runUpdate((Request) `drop Product`);
	 assertException("test16",
	 	void() { runQuery((Request) `from Product p select p`);});
	 
}

void test3() {
	 s = fetchSchema();
	 
	 // We need to fake the schema update
	 s.rels += { <"User", zero_one(), "foo", "bar", zero_one(), "Comment", false> };
	 s.placement += { << mongodb(), "Reviews" >,  "Comment"> };
	 runDDL((Request) `create Comment at Reviews`);
	 rs = runQuery((Request) `from Comment c select c`, s);
	 assertEquals("test17", rs,  <["c.@id"],[]>);
	 
}

void test4() {
	 runUpdate((Request) `drop Biography`);
	 assertException("test18",
	 void() { runQuery((Request) `from Biography b select b`);});
	 
}

void test5() {
	 s = fetchSchema();
	 
	 // We need to fake the schema update
	 s.rels += { <"Product", zero_one(), "bio", "product", zero_one(), "Biography", false> };
	 runDDL((Request) `create attribute bio at Inventory`);
	 
	 rs = runQuery((Request) `from CreditCard c select c`, s);
	 assertEquals("test15", rs,  <["c.@id"],[]>);
}

void runAll() {
	runTests([test1, test2, test3, test4]);
}

