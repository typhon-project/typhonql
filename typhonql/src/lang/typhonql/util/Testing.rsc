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

import IO;
import ParseTree;
import String;
import Map;

Log NO_LOG() = void(value v){ return; /*println("LOG: <v>"); */};
Log LOG = NO_LOG();

alias Conn = tuple[str host, str port, str user, str password];

data TestResult
  = threw(str msg)
  | failed()
  | success()
  ;

// key is assertion name for succes/fail
// or test function name for throw
alias Stats = map[str, TestResult];

Stats STATS = ();

alias PolystoreInstance =
	tuple[
		void() resetDatabases,
		ResultTable(Request req) runQuery,
		ResultTable(Request req, Schema s) runQueryForSchema,
		CommandResult(Request req) runUpdate,
		CommandResult(Request req, Schema s) runUpdateForSchema,
		CommandResult(Request req) runDDL,
		list[CommandResult](Request req, list[str] columnNames, list[list[str]] vs)
			runPreparedStatement,
		Schema() fetchSchema,
		void() printSchema];

alias TestExecuter =
	tuple[
		void(void(PolystoreInstance proxy)) runTest,
		void(list[void(PolystoreInstance proxy)]) runTests];
		
TestExecuter initTest(void(PolystoreInstance, bool) setup, str host, str port, str user, str password) {
	Conn conn = <host, port, user, password>;
	void() myResetDatabases = void() {
		resetDatabases(conn);
	};
	ResultTable(Request req) myRunQuery = ResultTable(Request req) {
		return runQuery(req, conn);
	};
	ResultTable(Request req, Schema s) myRunQueryForSchema = ResultTable(Request req, Schema s) {
		return runQuery(req, s, conn);
	};
	CommandResult(Request req) myRunUpdate = CommandResult(Request req) {
		return runUpdate(req, conn);
	};
	CommandResult(Request req, Schema s) myRunUpdateForSchema = CommandResult(Request req, Schema s) {
		return runUpdate(req, s, conn);
	};
	CommandResult(Request req) myRunDDL = CommandResult(Request req) {
		return runDDL(req, conn);
	};
	list[CommandResult](Request req, list[str] columnNames, list[list[str]] vs) 
		myRunPreparedStatement = list[CommandResult](Request req, list[str] columnNames, list[list[str]] vs) {
			return runPreparedUpdate(req, columnNames, vs, conn);
	};
	Schema() myFetchSchema = Schema() {
		return fetchSchema(conn);
	};
	
	void() myPrintSchema = void() {
		printSchema(conn);
	};
	
	PolystoreInstance proxy = <myResetDatabases, myRunQuery, myRunQueryForSchema,
		myRunUpdate, myRunUpdateForSchema, myRunDDL, myRunPreparedStatement, 
		myFetchSchema, myPrintSchema>;
	
	void(void(PolystoreInstance proxy)) myRunTest = void(void(PolystoreInstance proxy) t) {
		runTest(proxy, setup, t);
	};
	
	void(list[void(PolystoreInstance proxy)]) myRunTests = void(list[void(PolystoreInstance proxy)] ts) {
		runTests(proxy, setup, ts);
	};
	
	return <myRunTest, myRunTests>;
	
}

str notImplemented() {
	throw "Operation not implemented";
}

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java str readHttpModel(loc polystoreUri, str user, str password);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java map[str, Connection] readConnectionsInfo(str host, int port, str user, str password);


void printSchema(Conn c) {
	Schema sch = fetchSchema(c);
	iprintln(sch);
}

Schema fetchSchema(Conn c) {
	str modelStr = readHttpModel(|http://<c.host>:<c.port>|, c.user, c.password);
	Schema sch = loadSchemaFromXMI(modelStr);
	return sch;
}

CommandResult runDDL(Request req, Conn c) {
	map[str, Connection] connections =  readConnectionsInfo(c.host, toInt(c.port), c.user, c.password);
	Schema s = fetchSchema(c);
	return runDDL(req, s, c);
}

CommandResult runDDL(Request req, Schema s, Conn c) {
	map[str, Connection] connections =  readConnectionsInfo(c.host, toInt(c.port), c.user, c.password);
	Session session = newSession(connections, log = LOG);
	runDDL(req, s, session, log = LOG);
	return <-1, ()>;
}

CommandResult runUpdate(Request req, Conn c) {
	Schema s = fetchSchema(c);
	return runUpdate(req, s, c);
}

CommandResult runUpdate(Request req, Schema s, Conn c) {
	map[str, Connection] connections =  readConnectionsInfo(c.host, toInt(c.port), c.user, c.password);
	Session session = newSession(connections, log = LOG);
	return runUpdate(req, s, session, log = LOG);
}

list[CommandResult] runPreparedUpdate(Request req, list[str] columnNames, list[list[str]] vs, Conn c) {
	Schema s = fetchSchema(c);
	map[str, Connection] connections =  readConnectionsInfo(c.host, toInt(c.port), c.user, c.password);
	Session session = newSession(connections, log = LOG);
	return runPrepared(req, columnNames, vs, s, session, log = LOG);
}

ResultTable runQuery(Request req, Conn c) {
	map[str, Connection] connections =  readConnectionsInfo(c.host, toInt(c.port), c.user, c.password);
	Session session = newSession(connections, log = LOG);
	Schema s = fetchSchema(c);
	return runQuery(req, s, session, log = LOG);
}


ResultTable runQuery(Request req, Schema s, Conn c) {
	map[str, Connection] connections =  readConnectionsInfo(c.host, toInt(c.port), c.user, c.password);
	Session session = newSession(connections, log = LOG);
	return runQuery(req, s, session, log = LOG);
}

void resetDatabases(Conn c, Log log = LOG) {
	map[str, Connection] connections =  readConnectionsInfo(c.host, toInt(c.port), c.user, c.password);
	str modelStr = readHttpModel(|http://<c.host>:<c.port>|, c.user, c.password);
	Schema sch = loadSchemaFromXMI(modelStr);
	Session session = newSession(connections, log = log);
	runSchema(sch, session, log = log);
}

void runTest(PolystoreInstance proxy, void(PolystoreInstance, bool) setup, void(PolystoreInstance) t, Log log = LOG, bool runTestsInSetup = false) {
	println("Running test: <t>");
	proxy.resetDatabases();
	setup(proxy, runTestsInSetup);
	oldLog = LOG;
	LOG = log;
	try {
		t(proxy);
	}
	catch e: {
		STATS["<t>"] = threw("<e>");
		println (" <detailEmoji>: exception for `<t>`: <e>");
	}
	LOG = oldLog;
}

str successEmoji = "\u001b[32m☀ \u001b[0m";
str failEmoji = "\u001b[31m☁ \u001b[0m";
str detailEmoji = "\u001b[34m☢ \u001b[0m";

void assertEquals(str testName, value actual, value expected) {
	if (actual != expected) {
	    STATS[testName] = failed();
		println(" <failEmoji>: `<testName>` expected: <expected>, actual: <actual>");
	}
	else {
	    STATS[testName] = success();
		println(" <successEmoji>: `<testName>`");
	}	
}

void assertResultEquals(str testName, tuple[list[str] sig, list[list[value]] vals] actual, tuple[list[str] sig, list[list[value]] vals] expected) {
  if (actual.sig != expected.sig) {
    STATS[testName] = failed();
    println(" <failEmoji>: `<testName>` expected: <expected>, actual: <actual>");
  }
  else if (toSet(actual.vals) != toSet(expected.vals)) {
    STATS[testName] = failed();
    println(" <failEmoji>: `<testName>` expected: <expected>, actual: <actual>");
  }
  else {
    STATS[testName] = success();
	println(" <successEmoji>: `<testName>`");
  }
}

void assertException(str testName, void() block) {
	try {
		block();
		STATS[testName] = failed();
   		println(" <failEmoji>: `<testName>` expected exception");
	} 
	catch e: {
		STATS[testName] = success();
		println(" <successEmoji>: `<testName>`");
	}
}

void runTests(PolystoreInstance proxy, void(PolystoreInstance, bool) setup, list[void(PolystoreInstance)] tests, Log log = LOG /*void(value v) {println(v);}*/) {
	map[str, TestResult] stats = ();
	
	STATS = ();
	for (t <- tests) {
		runTest(proxy, setup, t, log = log);
	}
	
	println("# Summary");
	println("Number of tests: <size(tests)>");
	println("Number of asserts: <size([ k | str k <- STATS, STATS[k] in {failed(), success()} ])>");
	println("Number of success: <size([ k | str k <- STATS, STATS[k] == success() ])>");
	println("Number of failed: <size([ k | str k <- STATS, STATS[k] == failed() ])>");
	println("Number of throws: <size([ k | str k <- STATS, STATS[k] notin {failed(), success()} ])>");
	
	STATS = ();
	
	
}