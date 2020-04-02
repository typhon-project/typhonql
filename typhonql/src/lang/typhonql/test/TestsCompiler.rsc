module lang::typhonql::\test::TestsCompiler

import util::Eval;

import lang::typhonql::util::Log;


import lang::typhonql::TDBC;
import lang::typhonql::Session;
import lang::typhonql::Script;
import lang::typhonql::Request2Script;
import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonml::XMIReader;
import lang::typhonql::RunUsingCompiler;
import lang::typhonql::Run;

import IO;
import ParseTree;
import String;
import Map;

/*
 * These tests are meant to be run on a Typhon Polystore deployed according to the
 * resources/user-reviews-product folder
 */
 
 
str HOST = "localhost";
str PORT = "8080";
str user = "pablo";
str password = "antonio";

Log NO_LOG = void(value v){ return; };

Log LOG = NO_LOG;

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java str readHttpModel(loc polystoreUri, str user, str password);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java map[str, Connection] readConnectionsInfo(str host, int port, str user, str password);

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
	assertEquals("test5", rs,  <["b.text"],[["Chilean"]]>);
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

tuple[int, map[str,str]] runUpdate(Request req) {
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), user, password);
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema s = loadSchemaFromXMI(modelStr);
	return runUpdate(req, s, connections, log = LOG);
}

void runPreparedUpdate(Request req, list[str] columnNames, list[list[str]] vs) {
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), user, password);
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema s = loadSchemaFromXMI(modelStr);
	runPrepared(req, columnNames, vs, s, connections, log = LOG);
}

value runQuery(Request req) {
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), user, password);
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema s = loadSchemaFromXMI(modelStr);
	return runQuery(req, s, connections, log = LOG);
}

void printSchema() {
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	iprintln(sch);
}

Schema getSchema() {
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), user, password);
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	return sch;
}


void resetDatabases() {
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), user, password);
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	runSchema(sch, connections);
}

void runTest(void() t, Log log = NO_LOG) {
	resetDatabases();
	setup();
	oldLog = LOG;
	LOG = log;
	try {
		t();
	}
	catch e: {
		println ("Test [ <t> ] threw an exception: <e>");
	}
	LOG = oldLog;
}

void assertEquals(str testName, value actual, value expected) {
	if (actual != expected) {
		println("<testName> failed. Expected: <expected>, Actual: <actual>");
	}
	else {
		println("<testName> OK");
	}	
}

void runTests(Log log = NO_LOG) {
	tests = [test1, test2, test3, test4, test5,
		test6, test7, test8, test9, test10, test11, test12, test13];
	for (t <- tests) {
		runTest(t, log = log);
	}
}