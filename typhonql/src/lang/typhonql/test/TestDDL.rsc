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

Log LOG = void(value v) {;};

void setup(PolystoreInstance p) {
}

// DDL
 
// create entity (relational)
void test1(PolystoreInstance p) {
	 s = p.fetchSchema();
	 
	 // We need to fake the schema update
	 s.rels += { <"CreditCard", zero_one(), "foo", "bar", zero_one(), "User", false> };
	 s.placement += { << sql(), "Inventory" >,  "CreditCard"> };
	
     p.runDDL((Request) `create CreditCard at Inventory`);
	 
	 rs = p.runQueryForSchema((Request) `from CreditCard c select c`, s);
	 assertEquals("test1", rs,  <["c.@id"],[]>);
	 
}

// drop entity (relational)
void test2(PolystoreInstance p) {
	 p.runUpdate((Request) `drop Product`);
	 assertException("test2",
	 	void() { p.runQuery((Request) `from Product p select p`);});
	 
}

// create entity (document)
void test3(PolystoreInstance p) {
	 s = p.fetchSchema();
	 
	 // We need to fake the schema update
	 s.rels += { <"User", zero_one(), "foo", "bar", zero_one(), "Comment", false> };
	 s.placement += { << mongodb(), "Reviews" >,  "Comment"> };
	 p.runDDL((Request) `create Comment at Reviews`);
	 rs = p.runQueryForSchema((Request) `from Comment c select c`, s);
	 assertEquals("test3", rs,  <["c.@id"],[]>);
	 
}

// drop entity (document)
void test4(PolystoreInstance p) {
	 p.runUpdate((Request) `drop Biography`);
	 assertException("test4",
	 void() { p.runQuery((Request) `from Biography b select b`);});
	 
}

// create attribute (relational)
void test5(PolystoreInstance p) {
	 s = p.fetchSchema();
	 
	 // We need to fake the schema update
	 s.attrs += { <"Product", "availability", "int">};
	 p.runDDL((Request) `create Product.availability : int`);
	 p.runUpdateForSchema((Request) `insert Product {@id: #guitar, name: "Guitar", description: "Wood", availability: 50 }`, s);
	 rs = p.runQueryForSchema((Request) `from Product p select p.@id, p.availability`, s);
	 assertEquals("test5", rs,  <["p.@id", "p.availability"],[[ "guitar", 50 ]]>);
}

// create attribute (document)
void test6(PolystoreInstance p) {
	 s = p.fetchSchema();
	 
	 // We need to fake the schema update
	 s.attrs += { <"Biography", "rating", "int">};
	 p.runDDL((Request) `create Biography.rating : int`);
	 p.runUpdateForSchema((Request) `insert Biography {@id: #bio1, content: "Good guy", rating: 5 }`, s);
	 rs = p.runQueryForSchema((Request) `from Biography b select b.@id, b.rating`, s);
	 assertEquals("test6", rs,  <["b.@id", "b.rating"],[[ "bio1", 5 ]]>);
}


TestExecutor getExecutor() = initTest(setup, HOST, PORT, USER, PASSWORD);

void runTest(void(PolystoreInstance) t) {
	getExecutor().runTest(t); 
}

void runTests(list[void(PolystoreInstance)] ts) {
	getExecutor().runTests(ts); 
}

void runAll() {
	runTests([test1, test2, test3, test4]);
}
