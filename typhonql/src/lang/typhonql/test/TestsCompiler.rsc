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

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java str readHttpModel(loc polystoreUri, str user, str password);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java map[str, Connection] readConnectionsInfo(str host, int port, str user, str password);


void test1() {
	rs = runQuery((Request) `from Product p select p.name`);
	println(rs);
}

void test1b() {
	rs = runQuery((Request) `from Product p select p`);
	println(rs);
}

void test1c() {
	rs = runQuery((Request) `from Review r select r.contents`);
	println(rs);
}

void test1d() {
	rs = runQuery((Request) `from Review r select r`);
	println(rs);
}

void test1e() {
	rs = runQuery((Request) `from User u select u.biography.text where u == #victor`);
	println(rs);
}

void test1f() {
	rs = runQuery((Request) `from User u, Biography b select b.text where u.biography == b, u == #victor`);
	println(rs);
}


void test2() {
	runUpdate((Request) `insert User { @id: #pablo, name: "Pablo" }`);
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
	runUpdate((Request) `insert Review { @id: #rev, contents: "Good TV", user: #pablo }`);
}

void test5() {
	runUpdate((Request) `insert User { @id: #victor, name: "Víctor" }`);
	runUpdate((Request) `insert Biography { @id: #bio1, text: "Born in Chile", user: #victor }`);
}

void test6() {
	runUpdate((Request) `update Biography b where b.@id == #bio1 set { text:  "Another text" }`);
}

void test6b() {
	runUpdate((Request) `update User u where u.@id == #victor set { address:  "Fresia 898" }`);
}


void test7() {
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), user, password);
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema s = loadSchemaFromXMI(modelStr);
	Request cmd = (Request) `insert Product { name: ??name, description: ??description }`;
	rs = runPrepared(cmd, ["name", "description"],
						  [["\"IPhone\"", "\"Cool but expensive\""],
				           ["\"Samsung S10\"", "\"Less cool and still expensive\""]], s, connections);

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
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	iprintln(sch);
}


void resetDatabase() {
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), user, password);
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	runSchema("http://<HOST>:<PORT>", sch, connections);
}
