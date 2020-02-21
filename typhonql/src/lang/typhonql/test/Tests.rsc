module lang::typhonql::\test::Tests

import lang::typhonml::TyphonML;
import lang::typhonml::Util;
import lang::typhonql::Run;
import lang::typhonql::IDE;
import lang::typhonml::XMIReader;

import IO;
import String;

str HOST = "http://tijs-typhon.duckdns.org:8080";

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java Model bootConnections(loc polystoreUri, str user, str password);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java str readHttpModel(loc polystoreUri, str user, str password);

void test1() {
	str cmd = "insert Order {totalAmount: 32, products: [Product { name: \"TV\" } ]}";
	bootConnections(toLocation(HOST), "pablo", "antonio");
	str modelStr = readHttpModel(toLocation(HOST), "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	run(cmd, HOST, sch);
}

void test2() {
	str cmd = "from Product p select p";
	bootConnections(toLocation(HOST), "pablo", "antonio");
	str modelStr = readHttpModel(toLocation(HOST), "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	r = run(cmd, HOST, sch);
	println(r);
}

void test3() {
	str cmd = "insert User {name: \"Pablo\" }";
	bootConnections(toLocation(HOST), "pablo", "antonio");
	str modelStr = readHttpModel(toLocation(HOST), "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	run(cmd, HOST, sch);
}

void test3b() {
	str cmd = "insert Product {name: \"TV\", description: \"Flat\" }";
	bootConnections(toLocation(HOST), "pablo", "antonio");
	str modelStr = readHttpModel(toLocation(HOST), "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	run(cmd, HOST, sch);
}

void test4() {
	str cmd = "insert 
			  '@pablo User { name: \"Pablo\", reviews: badradio, biography: bio },
			  '@bio Biography { text: \"Born in Chile\" },
			  '@radio Product {name: \"TV\", description: \"Flat\", reviews: badradio },
			  '@badradio Review { contents: \"Good TV\",product: radio,user: pablo}";
	bootConnections(toLocation(HOST), "pablo", "antonio");
	str modelStr = readHttpModel(toLocation(HOST), "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	value v = run(cmd, HOST, sch);
	println(v);
}

void test5() {
	str cmd = "insert Product { name: ??, description: ?? }";
	bootConnections(toLocation(HOST), "pablo", "antonio");
	str modelStr = readHttpModel(toLocation(HOST), "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	rs = runPrepared(cmd, HOST, [["\"IPhone\"", "\"Cool but expensive\""],
													["\"Samsung S10\"", "\"Less cool and still expensive\""]], modelStr);
	println(rs);
}

void printSchema() {
	bootConnections(toLocation(HOST), "pablo", "antonio");
	str modelStr = readHttpModel(toLocation(HOST), "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	iprintln(sch);
}


void resetDatabase() {
	bootConnections(toLocation(HOST), "pablo", "antonio");
	str modelStr = readHttpModel(toLocation(HOST), "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	runSchema(HOST, sch);
}
