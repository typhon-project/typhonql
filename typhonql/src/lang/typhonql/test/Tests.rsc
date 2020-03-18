module lang::typhonql::\test::Tests

import lang::typhonml::TyphonML;
import lang::typhonml::Util;
import lang::typhonql::Run;
import lang::typhonql::IDE;
import lang::typhonml::XMIReader;
import lang::typhonql::Session;

import IO;
import String;

str HOST = "localhost";
str PORT = "8080";
str USER = "pablo";
str PASSWORD = "antonio";

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java str readHttpModel(loc polystoreUri, str user, str password);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java map[str, Connection] readConnectionsInfo(str host, int port, str user, str password);

void test1() {
	str cmd = "insert Order {totalAmount: 32, products: [Product { name: \"TV\" } ]}";
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), USER, PASSWORD);
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	run(cmd, sch, connections);
}

void test2() {
	str cmd = "from Product p select p";
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), USER, PASSWORD);
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	r = run(cmd, sch, connections);
	println(r);
}

void test3() {
	str cmd = "insert User {name: \"Pablo\" }";
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), USER, PASSWORD);
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	run(cmd, sch, connections);
}

void test3b() {
	str cmd = "insert Product {name: \"TV\", description: \"Flat\" }";
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), USER, PASSWORD);
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	run(cmd, sch, connections);
}

void test4() {
	str cmd = "insert 
			  '@pablo User { name: \"Pablo\", reviews: badradio, biography: bio },
			  '@bio Biography { text: \"Born in Chile\" },
			  '@radio Product {name: \"TV\", description: \"Flat\", reviews: badradio },
			  '@badradio Review { contents: \"Good TV\",product: radio,user: pablo}";
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), USER, PASSWORD);
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	value v = run(cmd, sch, connections);
	println(v);
}

void test5() {
	str cmd = "insert Product { name: ??name, description: ??description }";
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), USER, PASSWORD);
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	rs = runPrepared(cmd, ["name", "description"], [["\"IPhone\"", "\"Cool but expensive\""],
													["\"Samsung S10\"", "\"Less cool and still expensive\""]], modelStr, connections);
	println(rs);
}

void printSchema() {
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	iprintln(sch);
}


void resetDatabase() {
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), USER, PASSWORD);
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	runSchema(sch, connections);
}
