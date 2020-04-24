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
		void() startSession,
		void() closeSession,
		ResultTable(Request req) runQuery,
		ResultTable(Request req, Schema s) runQueryForSchema,
		CommandResult(Request req) runUpdate,
		CommandResult(Request req, Schema s) runUpdateForSchema,
		CommandResult(Request req) runDDL,
		list[CommandResult](Request req, list[str] columnNames, list[list[str]] vs)
			runPreparedUpdate,
		Schema() fetchSchema,
		void() printSchema];

alias TestExecuter =
	tuple[
		void(void(PolystoreInstance, bool), bool) runSetup,
		void(void(PolystoreInstance proxy)) runTest,
		void(list[void(PolystoreInstance proxy)]) runTests,
		Schema() fetchSchema];
		
TestExecuter initTest(void(PolystoreInstance, bool) setup, str host, str port, str user, str password, Log log = NO_LOG()) {
	Conn conn = <host, port, user, password>;
	Schema sch = fetchSchema(conn);
	map[str, Connection] connections =  readConnectionsInfo(conn.host, toInt(conn.port), conn.user, conn.password);
	Session session;
	
	void() myStartSession = void() {
		session = newSession(connections, log = LOG);
	};
	
	void() myCloseSession = void() {
		session.done();
	};
	
	void() myResetDatabases = void() {
		resetDatabasesInTest(sch, session);
	};
	ResultTable(Request req) myRunQuery = ResultTable(Request req) {
		return runQueryInTest(req, sch, session);
	};
	ResultTable(Request req, Schema s) myRunQueryForSchema = ResultTable(Request req, Schema s) {
		return runQueryInTest(req, s, session);
	};
	CommandResult(Request req) myRunUpdate = CommandResult(Request req) {
		return runUpdateInTest(req, sch, session);
	};
	CommandResult(Request req, Schema s) myRunUpdateForSchema = CommandResult(Request req, Schema s) {
		return runUpdateInTest(req, s, session);
	};
	CommandResult(Request req) myRunDDL = CommandResult(Request req) {
		return runDDLInTest(req, sch, conn);
	};
	list[CommandResult](Request req, list[str] columnNames, list[list[str]] vs) 
		myRunPreparedUpdate = list[CommandResult](Request req, list[str] columnNames, list[list[str]] vs) {
			return runPreparedUpdateInTest(req, columnNames, vs, sch, session);
	};
	Schema() myFetchSchema = Schema() {
		return fetchSchema(conn);
	};
	
	void() myPrintSchema = void() {
		printSchema(conn);
	};
	
	PolystoreInstance proxy = <myResetDatabases, myStartSession, myCloseSession, myRunQuery, myRunQueryForSchema,
		myRunUpdate, myRunUpdateForSchema, myRunDDL, myRunPreparedUpdate, 
		myFetchSchema, myPrintSchema>;
		
	void(void(PolystoreInstance, bool), bool) myRunSetup = void(void(PolystoreInstance, bool) setupFun, bool doTests) {
		proxy.startSession();
		setupFun(proxy, doTests);
		proxy.closeSession();
	};
	
	void(void(PolystoreInstance)) myRunTest = void(void(PolystoreInstance proxy) t) {
		runTest(proxy, setup, t, log);
	};
	
	void(list[void(PolystoreInstance)]) myRunTests = void(list[void(PolystoreInstance proxy)] ts) {
		runTests(proxy, setup, ts, log);
	};
	
	Schema() myfetchSchema = Schema() {
		return proxy.fetchSchema;
	};
	
	return <myRunSetup, myRunTest, myRunTests, myFetchSchema>;
	
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

CommandResult runDDLInTest(Request req, Schema s, Session session) {
	runDDL(req, s, session, log = LOG);
	return <-1, ()>;
}

CommandResult runUpdateInTest(Request req, Schema s, Session session) {
	return runUpdate(req, s, session, log = LOG);
}

list[CommandResult] runPreparedUpdateInTest(Request req, list[str] columnNames, list[list[str]] vs, Schema s, Session session) {
	return runPrepared(req, columnNames, vs, s, session, log = LOG);
}

ResultTable runQueryInTest(Request req, Schema s, Session session) {
	return runQuery(req, s, session, log = LOG);
}

void resetDatabasesInTest(Schema sch, Session session, Log log = LOG) {
	runSchema(sch, session, log = log);
}

void runTest(PolystoreInstance proxy, void(PolystoreInstance, bool) setup, void(PolystoreInstance) t, Log log = log, bool runTestsInSetup = false) {
	println("Running test: <t>");
	proxy.startSession();
	proxy.resetDatabases();
	setup(proxy, runTestsInSetup);
	oldLog = LOG;
	LOG = log;
	try {
		t(proxy);
		proxy.closeSession();
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

void runTests(PolystoreInstance proxy, void(PolystoreInstance, bool) setup, list[void(PolystoreInstance)] tests, Log log ,  bool runTestsInSetup = false/*void(value v) {println(v);}*/) {
	map[str, TestResult] stats = ();
	
	STATS = ();
	for (t <- tests) {
		runTest(proxy, setup, t, log = log, runTestsInSetup = runTestsInSetup);
	}
	
	println("# Summary");
	println("Number of tests: <size(tests)>");
	println("Number of asserts: <size([ k | str k <- STATS, STATS[k] in {failed(), success()} ])>");
	println("Number of success: <size([ k | str k <- STATS, STATS[k] == success() ])>");
	println("Number of failed: <size([ k | str k <- STATS, STATS[k] == failed() ])>");
	println("Number of throws: <size([ k | str k <- STATS, STATS[k] notin {failed(), success()} ])>");
	
	STATS = ();
	
	
}