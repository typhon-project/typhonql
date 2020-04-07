module lang::typhonql::\test::TestsCompiler

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

void test1() {
	rs = runQuery((Request) `from Product p select p.name`);
	assertEquals("test1", rs, <["p.name"],[["Radio"],["TV"]]>);
}

void test2() {
	rs = runQuery((Request) `from Product p select p`);
	assertEquals("test2", rs, <["p.@id"],[["radio"],["tv"]]>);
}

void test3() {
	rs = runQuery((Request) `from Review r select r.contents`);
	assertEquals("test3", rs,  <["r.contents"],[["Good TV"],[""],["***"]]>);
}

void test4() {
	rs = runQuery((Request) `from Review r select r`);
	assertEquals("test4", rs,  <["r.@id"],[["rev1"],["rev2"],["rev3"]]>);
}

void test5() {
	rs = runQuery((Request) `from User u select u.biography.text where u == #pablo`);
	assertEquals("test5", rs,  <["biography_0.text"],[["Chilean"]]>);
}

void test6() {
	rs = runQuery((Request) `from User u, Biography b select b.text where u.biography == b, u == #pablo`);
	assertEquals("test6", rs,   <["b.text"],[["Chilean"]]>);
}

void test7() {
	rs = runQuery((Request) `from User u, Review r select u.name, r.user where u.reviews == r, r.contents == "***"`);
	assertEquals("test7", rs, <["u.name","r.user"],[["Davy","davy"]]>);
}

void test8() {
	runUpdate((Request) `update Biography b where b.@id == #bio1 set { text:  "Simple" }`);
	rs = runQuery((Request) `from Biography b select b.text where b.@id == #bio1`);
	assertEquals("test8", rs, <["b.text"],[["Simple"]]>);
}

void test9() {
	runUpdate((Request) `update User u where u.@id == #pablo set { address:  "Fresia 8" }`);
	rs = runQuery((Request) `from User u select u.address where u.@id == #pablo`);
	assertEquals("test9", rs, <["u.address"],[["Fresia 8"]]>);
}


void test10() {
	res = runPreparedUpdate((Request) `insert Product { name: ??name, description: ??description }`,
						  ["name", "description"],
						  [["\"IPhone\"", "\"Apple\""],
				           ["\"Samsung S10\"", "\"Samsung\""]]);
	rs = runQuery((Request) `from Product p select p.name, p.description`);		    
	assertEquals("test10", rs,   
		<["p.name","p.description"],
		[["Samsung S10","Samsung"],["IPhone","Apple"],["Radio","Loud"],["TV","Flat"]]>);

}

void test11() {
	rs = runQuery((Request) `from User u select u.name where u.biography == #bio1`);
	assertEquals("test11", rs, <["u.name"],[["Pablo"]]>);
}

void test12() {
	runUpdate((Request) `insert @u1 User { @id: #tijs, name: "Tijs" }`);
	rs = runQuery((Request) `from User u select u where u.@id = #tijs`);
	assertEquals("test12", rs, <["u.@id"],[["tijs"]]>);
}

void test13() {
	<_, names> = runUpdate((Request) `insert User { name: "Tijs" }`);
	assertEquals("test13a", size(names), 1);
	uuid = names["uuid"];
	rs = runQuery([Request] "from User u select u where u.@id == #<uuid>");
	assertEquals("test13b", rs, <["u.@id"],[["<uuid>"]]>);
}

void test14() {
	runUpdate((Request) `insert User { @id: #tijs, name: "Tijs" }`);
	rs = runQuery((Request) `from User u select u where u.@id == #tijs`);
	assertEquals("test14", rs,  <["u.@id"],[[ "tijs" ]]>);
}


// DDL

void test15() {
	 s = fetchSchema();
	 
	 // We need to fake the schema update
	 s.rels += { <"CreditCard", zero_one(), "foo", "bar", zero_one(), "User", false> };
	 s.placement += { << sql(), "Inventory" >,  "CreditCard"> };
	
     runDDL((Request) `create CreditCard at Inventory`);
	 
	 rs = runQuery((Request) `from CreditCard c select c`, s);
	 assertEquals("test15", rs,  <["c.@id"],[]>);
	 
}

void test16() {
	 runUpdate((Request) `drop Product`);
	 assertException("test16",
	 	void() { runQuery((Request) `from Product p select p`);});
	 
}

void test17() {
	 s = fetchSchema();
	 
	 // We need to fake the schema update
	 s.rels += { <"User", zero_one(), "foo", "bar", zero_one(), "Comment", false> };
	 s.placement += { << sql(), "Reviews" >,  "Comment"> };
	
     runDDL((Request) `create Comment at Reviews`);
	 
	 rs = runQuery((Request) `from Comment c select c`, s);
	 assertEquals("test17", rs,  <["c.@id"],[]>);
	 
}

void test18() {
	 runUpdate((Request) `drop Biography`);
	 assertException("test18",
	 	void() { runQuery((Request) `from Biography b select b`);});
	 
}


