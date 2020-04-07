module lang::typhonql::util::Testing

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

Log NO_LOG = void(value v){ return; };

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java str readHttpModel(loc polystoreUri, str user, str password);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java map[str, Connection] readConnectionsInfo(str host, int port, str user, str password);


void printSchema() {
	Schema sch = fetchSchema();
	iprintln(sch);
}

Schema fetchSchema() {
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, USER, PASSWORD);
	Schema sch = loadSchemaFromXMI(modelStr);
	return sch;
}

tuple[int, map[str,str]] runDDL(Request req) {
	Schema s = fetchSchema();
	return runDDL(req, s);
}

tuple[int, map[str,str]] runDDL(Request req, Schema s) {
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), USER, PASSWORD);
	runDDL(req, s, connections, log = LOG);
	return <-1, ()>;
}

tuple[int, map[str,str]] runUpdate(Request req) {
	Schema s = fetchSchema();
	return runUpdate(req, s);
}

tuple[int, map[str,str]] runUpdate(Request req, Schema s) {
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), USER, PASSWORD);
	return runUpdate(req, s, connections, log = LOG);
}

void runPreparedUpdate(Request req, list[str] columnNames, list[list[str]] vs) {
	Schema s = fetchSchema();
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), USER, PASSWORD);
	runPrepared(req, columnNames, vs, s, connections, log = LOG);
}

value runQuery(Request req) {
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), USER, PASSWORD);
	Schema s = fetchSchema();
	return runQuery(req, s, connections, log = LOG);
}


value runQuery(Request req, Schema s) {
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), USER, PASSWORD);
	return runQuery(req, s, connections, log = LOG);
}

void resetDatabases() {
	map[str, Connection] connections =  readConnectionsInfo(HOST, toInt(PORT), USER, PASSWORD);
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, USER, PASSWORD);
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

void assertException(str testName, void() block) {
	try {
		block();
		println("<testName> failed. Expected exception.");
	} 
	catch e: {
		println("<testName> OK");
	}
}

void runTests(list[void()] tests, Log log = NO_LOG /*void(value v) {println(v);}*/) {
	for (t <- tests) {
		runTest(t, log = log);
	}
}