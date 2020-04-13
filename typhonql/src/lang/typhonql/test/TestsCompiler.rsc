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
 
 
str HOST = "192.168.178.78";
str PORT = "8080";
str USER = "admin";
str PASSWORD = "admin1@";

Log NO_LOG = void(value v){ return; /*println("LOG: <v>"); */};
public Log PRINT() = void(value v) { println("LOG: <v>"); };
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
	
	runUpdate((Request) `insert Tag { @id: #fun, name: "fun" }`);
	runUpdate((Request) `insert Tag { @id: #kitchen, name: "kitchen" }`);
	runUpdate((Request) `insert Tag { @id: #music, name: "music" }`);
	runUpdate((Request) `insert Tag { @id: #social, name: "social" }`);


	runUpdate((Request) `insert Item { @id: #tv1, shelf: 1, product: #tv }`);	
	runUpdate((Request) `insert Item { @id: #tv2, shelf: 1, product: #tv }`);	
	runUpdate((Request) `insert Item { @id: #tv3, shelf: 3, product: #tv }`);	
	runUpdate((Request) `insert Item { @id: #tv4, shelf: 3, product: #tv }`);
	
	runUpdate((Request) `insert Item { @id: #radio1, shelf: 2, product: #radio }`);	
	runUpdate((Request) `insert Item { @id: #radio2, shelf: 2, product: #radio }`);	
		
}


void testInsertManyXrefsSQLLocal() {
  runUpdate((Request)`insert Product {@id: #iphone, name: "iPhone", description: "Apple", tags: [#fun, #social]}`);
  rs = runQuery((Request)`from Product p select p.name where p.tags == #fun`);
  assertResultEquals("insertManyXrefsSQLLocal", rs, <["p.name"], [["iPhone"]]>);
}

void testInsertManyContainSQLtoExternal() {
  runUpdate((Request)`insert Review { @id: #newReview, contents: "expensive", user: #davy}`);
  runUpdate((Request)`insert Product {@id: #iphone, name: "iPhone", description: "Apple", reviews: [#newReview]}`);
  rs = runQuery((Request)`from Product p, Review r select r.content where p.@id == #iphone, p.reviews == #newReview`);
  assertResultEquals("InsertManyContainSQLtoExternal", rs, <["r.content"], [["iPhone"]]>);
}


void testUpdateManyXrefSQLLocal() {
  runUpdate((Request)`update Product p where p.@id == #tv set {tags +: [#fun, #social]}`);
  runUpdate((Request)`update Product p where p.@id == #radio set {tags +: [#fun, #music]}`);
  
  rs = runQuery((Request)`from Product p select p.name where p.tags == #fun`);
  assertResultEquals("updateManyXrefsSQLLocal", rs, <["p.name"], [["TV"], ["Radio"]]>);
}

void testUpdateManyXrefSQLLocalRemove() {
  runUpdate((Request)`update Product p where p.@id == #tv set {tags +: [#fun, #social]}`);
  runUpdate((Request)`update Product p where p.@id == #radio set {tags +: [#fun, #music]}`);
  
  runUpdate((Request)`update Product p where p.@id == #tv set {tags -: [#fun]}`);
  runUpdate((Request)`update Product p where p.@id == #radio set {tags -: [#fun]}`);
  
  rs = runQuery((Request)`from Product p select p.name where p.tags == #social`);
  assertResultEquals("updateManyXrefsSQLLocalRemove", rs, <["p.name"], [["TV"]]>);
}


void testUpdateManyXrefSQLLocalSet() {
  runUpdate((Request)`update Product p where p.@id == #tv set {tags: [#social]}`);
  runUpdate((Request)`update Product p where p.@id == #radio set {tags: [#music]}`);
  
  rs = runQuery((Request)`from Product p select p.name where p.tags == #social`);
  assertResultEquals("updateManyXrefsSQLLocalSet", rs, <["p.name"], [["TV"]]>);
}


void testUpdateManyXrefSQLLocalSetToEmpty() {
  runUpdate((Request)`update Product p where p.@id == #tv set {tags: [#social]}`);
  runUpdate((Request)`update Product p where p.@id == #radio set {tags: [#music]}`);

  runUpdate((Request)`update Product p where p.@id == #tv set {tags: []}`);
  runUpdate((Request)`update Product p where p.@id == #radio set {tags: []}`);
  
  rs = runQuery((Request)`from Product p select p.name where p.tags == #social`);
  assertResultEquals("updateManyXrefsSQLLocalSetToEmpty", rs, <["p.name"], []>);
}


void testUpdateManyContainSQLtoExternal() {
  runUpdate((Request)`insert Review { @id: #newReview, contents: "super!", user: #davy}`);
  runUpdate((Request)`update Product p where p.@id == #tv set {reviews +: [#newReview]}`);
  
  rs = runQuery((Request)`from Product p, Review r select r.content where p.@id == #tv, p.reviews == r`);
  assertResultEquals("updateManyContainSQLtoExternal", rs, <["r.content"], [["super!"], [""], ["Good TV"]]>);
}

void testUpdateManyContainSQLtoExternalRemove() {
  runUpdate((Request)`update Product p where p.@id == #tv set {reviews -: [#rev2]}`);
  
  rs = runQuery((Request)`from Product p, Review r select r.content where p.reviews == r, p.@id == #tv`);
  assertResultEquals("updateManyContainSQLtoExternalRemove", rs, <["r.content"], [["Good TV"]]>);
}


void testUpdateManyContainSQLtoExternalSet() {
  runUpdate((Request)`insert Review { @id: #newReview, contents: "super!", user: #davy}`);
  runUpdate((Request)`update Product p where p.@id == #tv set {reviews: [#newReview]}`);
  
  rs = runQuery((Request)`from Product p, Review r select r.content where p.@id == #tv, p.reviews == r`);
  assertResultEquals("updateManyContainSQLtoExternalSet", rs, <["r.content"], [["super!"]]>);
}

void testUpdateManyContainSQLtoExternalSetToEmpty() {
  runUpdate((Request)`update Product p where p.@id == #tv set {reviews: []}`);
  
  rs = runQuery((Request)`from Product p, Review r select r.content where p.reviews == r, p.@id == #tv`);
  assertResultEquals("updateManyContainSQLtoExternalSet", rs, <["r.content"], []>);
}


void testSelectViaSQLInverseLocal() {
  rs = runQuery((Request)`from Item i select i.shelf where i.product == #tv`);
  assertResultEquals("selectViaSQLInverseLocal", rs, <["i.shelf"], [[1], [1], [3], [3]]>);
}

void testSelectViaSQLKidLocal() {
  rs = runQuery((Request)`from Item i, Product p select i.shelf where p.@id == #tv, p.inventory == i`);
  assertResultEquals("selectViaSQLKidLocal", rs, <["i.shelf"], [[1], [1], [3], [3]]>);
}


void test1() {
	rs = runQuery((Request) `from Product p select p.name`);
	assertResultEquals("test1", rs, <["p.name"],[["Radio"],["TV"]]>);
}

void test2() {
	rs = runQuery((Request) `from Product p select p`);
	assertResultEquals("test2", rs, <["p.@id"],[["radio"],["tv"]]>);
}

void test3() {
	rs = runQuery((Request) `from Review r select r.contents`);
	assertResultEquals("test3", rs,  <["r.contents"],[["Good TV"],[""],["***"]]>);
}

void test4() {
	rs = runQuery((Request) `from Review r select r`);
	assertResultEquals("test4", rs,  <["r.@id"],[["rev1"],["rev2"],["rev3"]]>);
}

void test5() {
	rs = runQuery((Request) `from User u select u.biography.text where u == #pablo`);
	assertResultEquals("test5", rs,  <["biography_0.text"],[["Chilean"]]>);
}

void test6() {
	rs = runQuery((Request) `from User u, Biography b select b.text where u.biography == b, u == #pablo`);
	assertResultEquals("test6", rs,   <["b.text"],[["Chilean"]]>);
}

void test7() {
	rs = runQuery((Request) `from User u, Review r select u.name, r.user where u.reviews == r, r.contents == "***"`);
	assertResultEquals("test7", rs, <["u.name","r.user"],[["Davy","davy"]]>);
}

void test8() {
	runUpdate((Request) `update Biography b where b.@id == #bio1 set { text:  "Simple" }`);
	rs = runQuery((Request) `from Biography b select b.text where b.@id == #bio1`);
	assertResultEquals("test8", rs, <["b.text"],[["Simple"]]>);
}

void test9() {
	runUpdate((Request) `update User u where u.@id == #pablo set { address:  "Fresia 8" }`);
	rs = runQuery((Request) `from User u select u.address where u.@id == #pablo`);
	assertResultEquals("test9", rs, <["u.address"],[["Fresia 8"]]>);
}


void test10() {
	runPreparedUpdate((Request) `insert Product { name: ??name, description: ??description }`,
						  ["name", "description"],
						  [["\"IPhone\"", "\"Apple\""],
				           ["\"Samsung S10\"", "\"Samsung\""]]);
	rs = runQuery((Request) `from Product p select p.name, p.description`);		    
	assertResultEquals("test10", rs,   
		<["p.name","p.description"],
		[["Samsung S10","Samsung"],["IPhone","Apple"],["Radio","Loud"],["TV","Flat"]]>);

}

void test11() {
	rs = runQuery((Request) `from User u select u.name where u.biography == #bio1`);
	assertResultEquals("test11", rs, <["u.name"],[["Pablo"]]>);
}

void test12() {
	runUpdate((Request) `insert User { @id: #tijs, name: "Tijs" }`);
	rs = runQuery((Request) `from User u select u where u.@id == #tijs`);
	assertResultEquals("test12", rs, <["u.@id"],[["tijs"]]>);
}

void test13() {
	<_, names> = runUpdate((Request) `insert User { name: "Tijs" }`);
	assertEquals("test13a", size(names), 1);
	uuid = names["uuid"];
	rs = runQuery([Request] "from User u select u where u.@id == #<uuid>");
	assertResultEquals("test13b", rs, <["u.@id"],[["<uuid>"]]>);
}

tuple[int, map[str,str]] runUpdate(Request req) {
	return runUpdate(req, loadTestSchema(), testConnections(), log = LOG);
}

void runPreparedUpdate(Request req, list[str] columnNames, list[list[str]] vs) {
	runPrepared(req, columnNames, vs, loadTestSchema(), testConnections(), log = LOG);
}

value runQuery(Request req) {
	return runQuery(req, loadTestSchema(), testConnections(), log = LOG);
}

void printSchema() {
	iprintln(loadTestSchema());
}


map[str, Connection] testConnections() 
  = readConnectionsInfo(HOST, toInt(PORT), USER, PASSWORD);

Schema loadTestSchema() {
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, USER, PASSWORD);
	Schema sch = loadSchemaFromXMI(modelStr);
	return sch;
}


void resetDatabases() {
	runSchema(loadTestSchema(), testConnections());
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

void assertResultEquals(str testName, tuple[list[str] sig, list[list[value]] vals] actual, tuple[list[str] sig, list[list[value]] vals] expected) {
  if (actual.sig != expected.sig) {
    println("<testName> failed because of different result signatures. Expected: <expected>, Actual: <actual>");
  }
  else if (toSet(actual.vals) != toSet(expected.vals)) {
    println("<testName> failed because of different result sets. Expected: <expected>, Actual: <actual>");
  }
  else {
    println("<testName> OK");
  }
}


void runTests(Log log = NO_LOG /*void(value v) {println(v);}*/) {
	tests = [
	  testInsertManyXrefsSQLLocal
	  , testInsertManyContainSQLtoExternal
	  , testSelectViaSQLKidLocal
	  , testSelectViaSQLInverseLocal 
	  , testUpdateManyXrefSQLLocal
	  , testUpdateManyXrefSQLLocalRemove
	  , testUpdateManyXrefSQLLocalSet
	  , testUpdateManyXrefSQLLocalSetToEmpty
	  
	  , testUpdateManyContainSQLtoExternal
	  , testUpdateManyContainSQLtoExternalRemove
	  , testUpdateManyContainSQLtoExternalSet
	  , testUpdateManyContainSQLtoExternalSetToEmpty	  
	  , test1
	   , test2
	   , test3
	   , test4
	   , test5
	   , test6
		, test7
		, test8
		, test9
		, test10
		, test11
		, test12
		, test13
		];
	for (t <- tests) {
		runTest(t, log = log);
	}
}