module lang::typhonql::\test::Tests

import lang::typhonml::TyphonML;
import lang::typhonml::Util;
import lang::typhonql::Run;
import lang::typhonql::IDE;
import lang::typhonml::XMIReader;

import IO;
import String;

str HOST = "tijs-typhon.duckdns.org";
str PORT = "8080";

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java Model bootConnections(loc polystoreUri, str user, str password);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java Model bootConnections(loc polystoreUri, str host, str user, str password);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java str readHttpModel(loc polystoreUri, str user, str password);

void test1() {
	str cmd = "insert Order {totalAmount: 32, products: [Product { name: \"TV\" } ]}";
	bootConnections(|http://<HOST>:<PORT>|, HOST, "pablo", "antonio");
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	run(cmd, "http://<HOST>:<PORT>", sch);
}

void test2() {
	str cmd = "from Product p select p";
	bootConnections(|http://<HOST>:<PORT>|, HOST, "pablo", "antonio");
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	r = run(cmd, "http://<HOST>:<PORT>", sch);
	println(r);
}

void test3() {
	str cmd = "insert User {name: \"Pablo\" }";
	bootConnections(|http://<HOST>:<PORT>|, HOST, "pablo", "antonio");
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	run(cmd, "http://<HOST>:<PORT>", sch);
}

void test3b() {
	str cmd = "insert Product {name: \"TV\", description: \"Flat\" }";
	bootConnections(|http://<HOST>:<PORT>|, HOST, "pablo", "antonio");
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	run(cmd, "http://<HOST>:<PORT>", sch);
}

void test4() {
	str cmd = "insert 
			  '@pablo User { name: \"Pablo\", reviews: badradio, biography: bio },
			  '@bio Biography { text: \"Born in Chile\" },
			  '@radio Product {name: \"TV\", description: \"Flat\", reviews: badradio },
			  '@badradio Review { contents: \"Good TV\",product: radio,user: pablo}";
	bootConnections(|http://<HOST>:<PORT>|, HOST, "pablo", "antonio");
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	value v = run(cmd, "http://<HOST>:<PORT>", sch);
	println(v);
}

void test5() {
	str cmd = "insert Product { name: ??, description: ?? }";
	bootConnections(|http://<HOST>:<PORT>|, HOST, "pablo", "antonio");
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	rs = runPrepared(cmd, "http://<HOST>:<PORT>", [["\"IPhone\"", "\"Cool but expensive\""],
													["\"Samsung S10\"", "\"Less cool and still expensive\""]], modelStr);
	println(rs);
}

void printSchema() {
	bootConnections(|http://<HOST>:<PORT>|, HOST, "pablo", "antonio");
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	iprintln(sch);
}


void resetDatabase() {
	bootConnections(|http://<HOST>:<PORT>|, HOST, "pablo", "antonio");
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	runSchema("http://<HOST>:<PORT>", sch);
}
