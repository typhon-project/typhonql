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
import List;
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

void setup(bool doTest=false) {
	runUpdate((Request) `insert User { @id: #pablo, name: "Pablo" }`);
	runUpdate((Request) `insert User { @id: #davy, name: "Davy" }`);
	
	if (doTest) {
	  rs = runQuery((Request)`from User u select u.@id, u.name`);
	  assertResultEquals("users were inserted", rs, <["u.@id", "u.name"], [["pablo", "Pablo"], ["davy", "Davy"]]>);
	}
	
	runUpdate((Request) `insert Product {@id: #tv, name: "TV", description: "Flat", productionDate:  $2020-04-13$ }`);
	runUpdate((Request) `insert Product {@id: #radio, name: "Radio", description: "Loud" , productionDate:  $2020-04-13$ }`);
	
	if (doTest) {
	  rs = runQuery((Request)`from Product p select p.@id, p.name, p.description, p.productionDate`);
	  assertResultEquals("products were inserted", rs, <["p.@id", "p.name", "p.description", "p.productionDate"], 
	     [["tv", "TV", "Flat", $2020-04-12T22:00:00.000+00:00$], ["radio", "Radio", "Loud", $2020-04-12T22:00:00.000+00:00$]]>);
	}
	
	
	runUpdate((Request) `insert Review { @id: #rev1, contents: "Good TV", user: #pablo, product: #tv }`);
	runUpdate((Request) `insert Review { @id: #rev2, contents: "", user: #davy, product: #tv }`);
	runUpdate((Request) `insert Review { @id: #rev3, contents: "***", user: #davy, product: #radio }`);
	
	if (doTest) {
	  rs = runQuery((Request)`from Review r select r.@id, r.contents, r.user, r.product`);
	  assertResultEquals("reviews were inserted", rs, <["r.@id", "r.contents", "r.user", "r.product"], 
	     [["rev1", "Good TV", "pablo", "tv"], 
	      ["rev2", "", "davy", "tv"],
	      ["rev3", "***", "davy", "radio"]
	      ]>);
	      
	  rs = runQuery((Request)`from Product p select p.reviews`);
	  assertResultEquals("reviews obtained from product", rs, <["p.reviews"], [["rev1"], ["rev2"], ["rev3"]]>);

	  rs = runQuery((Request)`from User u select u.reviews`);
	  assertResultEquals("reviews obtained from user", rs, <["u.reviews"], [["rev1"], ["rev2"], ["rev3"]]>);
	}
	
	
	
	runUpdate((Request) `insert Biography { @id: #bio1, text: "Chilean", user: #pablo }`);
	
	if (doTest) {
	  rs = runQuery((Request)`from Biography b select b.@id, b.text, b.user`);
	  assertResultEquals("bios were inserted", rs, <["b.@id", "b.text", "b.user"], 
	    [["bio1", "Chilean", "pablo"]]>);
	    
	  rs = runQuery((Request)`from User u select u.biography`);
	  // the fact that there's null (i.e., <false, "">) here means that
	  // there are users without bios
	  assertResultEquals("bio obtained from user", rs, <["u.biography"], [["bio1"], [<false, "">]]>);  
	}
	
	runUpdate((Request) `insert Tag { @id: #fun, name: "fun" }`);
	runUpdate((Request) `insert Tag { @id: #kitchen, name: "kitchen" }`);
	runUpdate((Request) `insert Tag { @id: #music, name: "music" }`);
	runUpdate((Request) `insert Tag { @id: #social, name: "social" }`);

    if (doTest) {
      rs = runQuery((Request)`from Tag t select t.@id, t.name`);
      assertResultEquals("tags were inserted", rs, <["t.@id", "t.name"], [
        ["fun", "fun"],
        ["kitchen", "kitchen"],
        ["music", "music"],
        ["social", "social"]
      ]>);
    }


	runUpdate((Request) `insert Item { @id: #tv1, shelf: 1, product: #tv }`);	
	runUpdate((Request) `insert Item { @id: #tv2, shelf: 1, product: #tv }`);	
	runUpdate((Request) `insert Item { @id: #tv3, shelf: 3, product: #tv }`);	
	runUpdate((Request) `insert Item { @id: #tv4, shelf: 3, product: #tv }`);
	
	runUpdate((Request) `insert Item { @id: #radio1, shelf: 2, product: #radio }`);	
	runUpdate((Request) `insert Item { @id: #radio2, shelf: 2, product: #radio }`);
	
	if (doTest) {
	  rs = runQuery((Request)`from Item i select i.@id, i.shelf, i.product`);
	  assertResultEquals("items were inserted", rs, <["i.@id", "i.shelf", "i.product"], [
	    ["tv1", 1, "tv"],
	    ["tv2", 1, "tv"],
	    ["tv3", 3, "tv"],
	    ["tv4", 3, "tv"],
	    ["radio1", 2, "radio"],
	    ["radio2", 2, "radio"]
	  ]>);
	  
	  rs = runQuery((Request)`from Product p select p.inventory where p.@id == #tv`);
	  assertResultEquals("tv inventory obtained", rs, <["p.inventory"], [["tv1"], ["tv2"], ["tv3"], ["tv4"]]>);
	  
	  rs = runQuery((Request)`from Product p select p.inventory where p.@id == #radio`);
	  assertResultEquals("radio inventory obtained", rs, <["p.inventory"], [["radio1"], ["radio2"]]>);
	}	
		
}


void testSetup(Log log = NO_LOG) {
  Log oldLog = LOG;
  LOG = log;
  println("Doing sanity check on setup");
  resetDatabases();
  setup(doTest=true);
  LOG = oldLog;
}

void testInsertSingleValuedSQLCross() {
  runUpdate((Request)`insert Category {@id: #appliances, id: "appliances", name: "Home Appliances"}`);
  
  rs = runQuery((Request)`from Category c select c.name where c.@id == #appliances`);
  assertResultEquals("category name obtained from mongo", rs, <["c.name"],[["Home Appliances"]]>);
  
  runUpdate((Request)`insert Product {@id: #nespresso, 
  					 '  name: "Nespresso", 
  					 '  price: 23, 
  					 '  productionDate: $2020-04-15$,
  					 '  category: #appliances
  					 '}`);

  rs = runQuery((Request)`from Product p select p.name where p.category == #appliances`);
  assertResultEquals("product by category", rs, <["p.name"],[["Nespresso"]]>);
}

void testInsertManyValuedSQLLocal() {
  // TODO: this shows the cyclic reference problem we still need to solve.
  runUpdate((Request)`insert Item { @id: #laptop1, shelf: 1, product: #laptop}`);	
  runUpdate((Request)`insert Item { @id: #laptop2, shelf: 1, product: #laptop}`);	
	
  runUpdate((Request)`insert Product { @id: #laptop, name: "MacBook", inventory: [#laptop1, #laptop2]}`);
  
  rs = runQuery((Request)`from Product p select p.inventory where p.@id == #laptop`);
  
  assertResultEquals("many-valued inventory obtained from product", rs, <["p.inventory"],
      [["laptop1"], ["laptop2"]]>);
  
  rs = runQuery((Request)`from Item i select i.@id where i.product == #laptop`);
  assertResultEquals("many-valued inventory obtained via inverse", rs, <["i.@id"],
      [["laptop1"], ["laptop2"]]>);
  
}

void testDeleteAllSQLBasic() {
  runUpdate((Request)`delete Tag t`);
  rs = runQuery((Request)`from Tag t select t`);
  assertResultEquals("deleteAllSQLBasic", rs, <["t.@id"], []>);
}

void testDeleteAllWithCascade() {
  runUpdate((Request)`delete Product p where p.@id == #tv`);
  
  rs = runQuery((Request)`from Item i select i.@id where i.product == #tv`);
  assertResultEquals("deleting products deletes items", rs, <["i.@id"], []>);
  
  rs = runQuery((Request)`from Review r select r.@id where r.product == #tv`);
  assertResultEquals("deleting products deletes reviews", rs, <["t.@id"], []>);

  rs = runQuery((Request)`from Tag t select t.@id`);
  assertResultEquals("deleting products does not delete tags", rs, <["t.@id"], [["fun"], ["kitchen"], ["music"], ["social"]]>);
}


void testDeleteKidsRemovesParentLinksSQLLocal() {
  runUpdate((Request)`delete Item i where i.product == #tv`);
  
  rs = runQuery((Request)`from Product p select p.inventory`);
  assertResultEquals("delete items removes from inventory", <["p.inventory"], []>);
}
void testDeleteKidsRemovesParentLinksSQLCross() {
  runUpdate((Request)`delete Review r where r.product == #tv`);
  
  rs = runQuery((Request)`from Product p select p.reviews`);
  assertResultEquals("delete reviews removes from product reviews", <["p.reviews"], []>);
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


void testSQLDateEquals() {
  rs = runQuery((Request)`from Product p select p.name where p.productionDate == $2020-04-13$`);
  assertResultEquals("sqlDateEquals", rs, <["p.name"], [["Radio"],["TV"]]>);
}

void test1() {
	rs = runQuery((Request) `from Product p select p.name`);
	assertResultEquals("name is selected from product", rs, <["p.name"],[["Radio"],["TV"]]>);
}

void test2() {
	rs = runQuery((Request) `from Product p select p`);
	assertResultEquals("product ids are selected", rs, <["p.@id"],[["radio"],["tv"]]>);
}

void test3() {
	rs = runQuery((Request) `from Review r select r.contents`);
	assertResultEquals("review contents is selected", rs,  <["r.contents"],[["Good TV"],[""],["***"]]>);
}

void test4() {
	rs = runQuery((Request) `from Review r select r`);
	assertResultEquals("review ids are selected", rs,  <["r.@id"],[["rev1"],["rev2"],["rev3"]]>);
}

void test5() {
	rs = runQuery((Request) `from User u select u.biography.text where u == #pablo`);
	assertResultEquals("two-level navigation to attribute", rs,  <["biography_0.text"],[["Chilean"]]>);
}

void test6() {
	rs = runQuery((Request) `from User u, Biography b select b.text where u.biography == b, u == #pablo`);
	assertResultEquals("navigating via where-clauses", rs,   <["b.text"],[["Chilean"]]>);
}

void test7() {
	rs = runQuery((Request) `from User u, Review r select u.name, r.user where u.reviews == r, r.contents == "***"`);
	assertResultEquals("fields from different entities", rs, <["u.name","r.user"],[["Davy","davy"]]>);
}

void test8() {
	runUpdate((Request) `update Biography b where b.@id == #bio1 set { text:  "Simple" }`);
	rs = runQuery((Request) `from Biography b select b.text where b.@id == #bio1`);
	assertResultEquals("basic update of attribute on mongo", rs, <["b.text"],[["Simple"]]>);
}

void test9() {
	runUpdate((Request) `update User u where u.@id == #pablo set { address:  "Fresia 8" }`);
	rs = runQuery((Request) `from User u select u.address where u.@id == #pablo`);
	assertResultEquals("basic update of attribute on sql", rs, <["u.address"],[["Fresia 8"]]>);
}


void test10() {
	runPreparedUpdate((Request) `insert Product { name: ??name, description: ??description }`,
						  ["name", "description"],
						  [["\"IPhone\"", "\"Apple\""],
				           ["\"Samsung S10\"", "\"Samsung\""]]);
	rs = runQuery((Request) `from Product p select p.name, p.description`);		    
	assertResultEquals("prepared insert statement on sql", rs,   
		<["p.name","p.description"],
		[["Samsung S10","Samsung"],["IPhone","Apple"],["Radio","Loud"],["TV","Flat"]]>);

}

void test11() {
	rs = runQuery((Request) `from User u select u.name where u.biography == #bio1`);
	assertResultEquals("filter on external relation in sql", rs, <["u.name"],[["Pablo"]]>);
}

void test12() {
	runUpdate((Request) `insert User { @id: #tijs, name: "Tijs" }`);
	rs = runQuery((Request) `from User u select u where u.@id == #tijs`);
	assertResultEquals("basic insert in sql", rs, <["u.@id"],[["tijs"]]>);
}

void test13() {
	<_, names> = runUpdate((Request) `insert User { name: "Tijs" }`);
	assertEquals("one insert is one object inserted", size(names), 1);
	uuid = names["uuid"];
	rs = runQuery([Request] "from User u select u where u.@id == #<uuid>");
	assertResultEquals("generated id is in the result", rs, <["u.@id"],[["<uuid>"]]>);
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


data TestResult
  = threw(str msg)
  | failed()
  | success()
  ;

// key is assertion name for succes/fail
// or test function name for throw
private map[str, TestResult] STATS = ();

void runTest(void() t, Log log = NO_LOG) {
	println("Running test: <t>");
	resetDatabases();
	setup();
	oldLog = LOG;
	LOG = log;
	try {
		t();
	}
	catch e: {
	    STATS["<t>"] = threw("<e>");
		println (" ⚠: exception for `<t>`: <e>");
	}
	LOG = oldLog;
}

void assertEquals(str testName, value actual, value expected) {
	if (actual != expected) {
	    STATS[testName] = failed();
		println(" ✗: `<testName>` expected: <expected>, actual: <actual>");
	}
	else {
	    STATS[testName] = success();
		println(" ✔: `<testName>`");
	}	
}

void assertResultEquals(str testName, tuple[list[str] sig, list[list[value]] vals] actual, tuple[list[str] sig, list[list[value]] vals] expected) {
  if (actual.sig != expected.sig) {
    STATS[testName] = failed();
    println(" ✗: `<testName>` expected: <expected>, actual: <actual>");
  }
  else if (toSet(actual.vals) != toSet(expected.vals)) {
    STATS[testName] = failed();
    println(" ✗: `<testName>` expected: <expected>, actual: <actual>");
  }
  else {
    STATS[testName] = success();
	println(" ✔: `<testName>`");
  }
}


void runTests(Log log = NO_LOG /*void(value v) {println(v);}*/) {
	tests = [
	   testInsertSingleValuedSQLCross
	  , testInsertManyValuedSQLLocal
	  , testDeleteAllSQLBasic
	  , testDeleteAllWithCascade
	  , testDeleteKidsRemovesParentLinksSQLLocal
	  , testDeleteKidsRemovesParentLinksSQLCross

	  , testInsertManyXrefsSQLLocal
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
	  
	  , testSQLDateEquals
	  
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
	
	STATS = ();
	for (t <- tests) {
	    runTest(t, log = log);
	}
	
	println("# Summary");
	println("Number of tests: <size(tests)>");
	println("Number of asserts: <size([ k | str k <- STATS, STATS[k] in {failed(), success()} ])>");
	println("Number of success: <size([ k | str k <- STATS, STATS[k] == success() ])>");
	println("Number of failed: <size([ k | str k <- STATS, STATS[k] == failed() ])>");
	println("Number of throws: <size([ k | str k <- STATS, STATS[k] notin {failed(), success()} ])>");
	
}