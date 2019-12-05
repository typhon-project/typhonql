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
	Schema sch = getSchema(|http://localhost:8080|, "pablo", "antonio");
	run(cmd, "http://localhost:8080", sch);
}

void test2() {
	str cmd = "from Order o select o";
	bootConnections(|http://localhost:8080|, "pablo", "antonio");
	Schema sch = getSchema(|http://localhost:8080|, "pablo", "antonio");
	r = run(cmd, "http://localhost:8080", sch);
	println(r);
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
