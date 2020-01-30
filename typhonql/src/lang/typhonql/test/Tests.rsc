module lang::typhonql::\test::Tests

import lang::typhonml::TyphonML;
import lang::typhonml::Util;
import lang::typhonql::Run;
import lang::typhonql::IDE;
import lang::typhonml::XMIReader;

import IO;

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java Model bootConnections(loc polystoreUri, str user, str password);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java str readHttpModel(loc polystoreUri, str user, str password);

void test1() {
	str cmd = "insert Order {totalAmount: 32, products: [Product { name: \"TV\" } ]}";
	bootConnections(|http://localhost:8080|, "pablo", "antonio");
	str modelStr = readHttpModel(|http://localhost:8080|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	run(cmd, "http://localhost:8080", sch);
}

void test2() {
	str cmd = "from Product p select p";
	bootConnections(|http://localhost:8080|, "pablo", "antonio");
	str modelStr = readHttpModel(|http://localhost:8080|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	r = run(cmd, "http://localhost:8080", sch);
	println(r);
}

void test3() {
	str cmd = "insert User {name: \"Pablo\" }";
	bootConnections(|http://localhost:8080|, "pablo", "antonio");
	str modelStr = readHttpModel(|http://localhost:8080|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	run(cmd, "http://localhost:8080", sch);
}


void test4() {
	str cmd = "insert 
			  '@pablo User { name: \"Claudio\", reviews: badradio },
			  '@radio Product {name: \"TV\", description: \"Flat\", reviews: badradio },
			  '@badradio Review { contents: \"Good TV\",product: radio,user: pablo}";
	bootConnections(|http://localhost:8080|, "pablo", "antonio");
	str modelStr = readHttpModel(|http://localhost:8080|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	value v = run(cmd, "http://localhost:8080", sch);
	println(v);
}

void printSchema() {
	bootConnections(|http://localhost:8080|, "pablo", "antonio");
	str modelStr = readHttpModel(|http://localhost:8080|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	iprintln(sch);
}


void resetDatabase() {
	bootConnections(|http://localhost:8080|, "pablo", "antonio");
	str modelStr = readHttpModel(|http://localhost:8080|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	runSchema("http://localhost:8080", sch);
}
