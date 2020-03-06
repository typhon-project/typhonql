module lang::typhonql::\test::TestsCompiler

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


str HOST = "localhost";
str PORT = "8080";
str user = "pablo";
str password = "antonio";

map[str, Connection] connections = (
			"Reviews" : mongoConnection(HOST, 27018, "admin", "admin"),
 			"Inventory" : sqlConnection(HOST, 3306, "root", "example")
	);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java str readHttpModel(loc polystoreUri, str user, str password);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java map[str, Connection] readConnectionsInfo(str host, int port, str user, str password);


void test1() {
	rs = runQuery((Request) `from Product p select p`);
	println(rs);
}

void test2() {
	runUpdate((Request) `insert User {name: "Pablo" }`);
}

void test3() {
	runUpdate((Request) `insert Product {name: "TV", description: "Flat" }`);
}

void test4() {
	/*
	str cmd = "insert 
			  '@pablo User { name: \"Pablo\", reviews: badradio, biography: bio },
			  '@bio Biography { text: \"Born in Chile\" },
			  '@radio Product {name: \"TV\", description: \"Flat\", reviews: badradio },
			  '@badradio Review { contents: \"Good TV\",product: radio,user: pablo}";
	*/
}

void test5() {
	str cmd = "insert Product { name: ??, description: ?? }";
	/*rs = runPrepared(cmd, "http://<HOST>:<PORT>", [["\"IPhone\"", "\"Cool but expensive\""],
													["\"Samsung S10\"", "\"Less cool and still expensive\""]], modelStr);
	*/
}

void runUpdate(Request req) {
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), user, password);
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema s = loadSchemaFromXMI(modelStr);
	runUpdate(req, s, connections);
}

value runQuery(Request req) {
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), user, password);
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema s = loadSchemaFromXMI(modelStr);
	return runQuery(req, s, connections);
}

void printSchema() {
	bootConnections(|http://<HOST>:<PORT>|, HOST, "pablo", "antonio");
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	iprintln(sch);
}


void resetDatabase() {
	@javaClass{nl.cwi.swat.typhonql.TyphonQL}
	java Model bootConnections(loc polystoreUri, str user, str password);
	
	bootConnections(|http://<HOST>:<PORT>|, "pablo", "antonio");
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	runSchema("http://<HOST>:<PORT>", sch);
}
