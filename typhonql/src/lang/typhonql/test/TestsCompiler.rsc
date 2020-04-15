module lang::typhonql::\test::TestsCompiler

import lang::typhonql::util::Log;
import lang::typhonql::util::Testing;

import IO;

import lang::typhonml::Util;

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
	p.runUpdate((Request) `insert User { @id: #pablo, name: "Pablo" }`);
	p.runUpdate((Request) `insert User { @id: #davy, name: "Davy" }`);
	
	p.runUpdate((Request) `insert Product {@id: #tv, name: "TV", description: "Flat" }`);
	p.runUpdate((Request) `insert Product {@id: #radio, name: "Radio", description: "Loud" }`);
	
	p.runUpdate((Request) `insert Review { @id: #rev1, contents: "Good TV", user: #pablo, product: #tv }`);
	p.runUpdate((Request) `insert Review { @id: #rev2, contents: "", user: #davy, product: #tv }`);
	p.runUpdate((Request) `insert Review { @id: #rev3, contents: "***", user: #davy, product: #radio }`);
	
	p.runUpdate((Request) `insert Biography { @id: #bio1, text: "Chilean", user: #pablo }`);
}

void test1(PolystoreInstance p) {
	rs = p.runQuery((Request) `from Product p select p.name`);
	println(rs);
	assertEquals("test1", rs, <["p.name"],[["Radio"],["TV"]]>);
}

void test2(PolystoreInstance p) {
	rs = p.runQuery((Request) `from Product p select p`);
	assertEquals("test2", rs, <["p.@id"],[["radio"],["tv"]]>);
}

void test3(PolystoreInstance p) {
	rs = p.runQuery((Request) `from Review r select r.contents`);
	assertEquals("test3", rs,  <["r.contents"],[["Good TV"],[""],["***"]]>);
}

void test4(PolystoreInstance p) {
	rs = p.runQuery((Request) `from Review r select r`);
	assertEquals("test4", rs,  <["r.@id"],[["rev1"],["rev2"],["rev3"]]>);
}

void test5(PolystoreInstance p) {
	rs = p.runQuery((Request) `from User u select u.biography.text where u == #pablo`);
	assertEquals("test5", rs,  <["biography_0.text"],[["Chilean"]]>);
}

void test6(PolystoreInstance p) {
	rs = p.runQuery((Request) `from User u, Biography b select b.text where u.biography == b, u == #pablo`);
	assertEquals("test6", rs,   <["b.text"],[["Chilean"]]>);
}

void test7(PolystoreInstance p) {
	rs = p.runQuery((Request) `from User u, Review r select u.name, r.user where u.reviews == r, r.contents == "***"`);
	assertEquals("test7", rs, <["u.name","r.user"],[["Davy","davy"]]>);
}

void test8(PolystoreInstance p) {
	p.runUpdate((Request) `update Biography b where b.@id == #bio1 set { text:  "Simple" }`);
	rs = p.runQuery((Request) `from Biography b select b.text where b.@id == #bio1`);
	assertEquals("test8", rs, <["b.text"],[["Simple"]]>);
}

void test9(PolystoreInstance p) {
	p.runUpdate((Request) `update User u where u.@id == #pablo set { address:  "Fresia 8" }`);
	rs = p.runQuery((Request) `from User u select u.address where u.@id == #pablo`);
	assertEquals("test9", rs, <["u.address"],[["Fresia 8"]]>);
}


void test10(PolystoreInstance p) {
	res = p.runPreparedUpdate((Request) `insert Product { name: ??name, description: ??description }`,
						  ["name", "description"],
						  [["\"IPhone\"", "\"Apple\""],
				           ["\"Samsung S10\"", "\"Samsung\""]]);
	rs = p.runQuery((Request) `from Product p select p.name, p.description`);		    
	assertEquals("test10", rs,   
		<["p.name","p.description"],
		[["Samsung S10","Samsung"],["IPhone","Apple"],["Radio","Loud"],["TV","Flat"]]>);

}

void test11(PolystoreInstance p) {
	rs = p.runQuery((Request) `from User u select u.name where u.biography == #bio1`);
	assertEquals("test11", rs, <["u.name"],[["Pablo"]]>);
}

void test12(PolystoreInstance p) {
	p.runUpdate((Request) `insert @u1 User { @id: #tijs, name: "Tijs" }`);
	rs = p.runQuery((Request) `from User u select u where u.@id = #tijs`);
	assertEquals("test12", rs, <["u.@id"],[["tijs"]]>);
}

void test13(PolystoreInstance p) {
	<_, names> = p.runUpdate((Request) `insert User { name: "Tijs" }`);
	assertEquals("test13a", size(names), 1);
	uuid = names["uuid"];
	rs = p.runQuery([Request] "from User u select u where u.@id == #<uuid>");
	assertEquals("test13b", rs, <["u.@id"],[["<uuid>"]]>);
}

void test14(PolystoreInstance p) {
	p.runUpdate((Request) `insert User { @id: #tijs, name: "Tijs" }`);
	rs = p.runQuery((Request) `from User u select u where u.@id == #tijs`);
	assertEquals("test14", rs,  <["u.@id"],[[ "tijs" ]]>);
}

TestExecutor getExecutor() = initTest(setup, HOST, PORT, USER, PASSWORD);

void runTest(void(PolystoreInstance) t) {
	getExecutor().runTest(t); 
}

void runTests(list[void(PolystoreInstance)] ts) {
	getExecutor().runTests(ts); 
}

void runAll() {
	runTests([test1, test2, test3, test4, test5, test6,
		test7, test8, test9, test10, test11,
		test13, test14]);
}

Schema fetchSchema() {
	getExecutor().fetchSchema();
}

Schema printSchema() {
	getExecutor().printSchema();
}

