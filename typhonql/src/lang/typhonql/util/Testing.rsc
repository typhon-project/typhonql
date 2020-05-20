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

alias Conn = tuple[str host, str port, str user, str password];

data TestResult
  = threw(str msg)
  | failed()
  | success()
  ;

// key is assertion name for succes/fail
// or test function name for throw
alias Stats = map[str, TestResult];

alias PolystoreInstance =
	tuple[
		void() resetStats,
		Stats() getStats,
		void(str key, TestResult result) setStat,		
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
		void() printSchema,
		void (str testName, value actual, value expected) assertEquals,
		void(str testName, tuple[list[str] sig, list[list[value]] vals] actual, tuple[list[str] sig, list[list[value]] vals] expected) assertResultEquals,
		void (str testName, void() block)  assertException
	];

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
	
	Stats stats = ();
	
	void() myResetStats = void() {
		stats = ();
	};
	
	Stats() myGetStats = Stats() {
		return stats;
	};
	
	void(str key, TestResult result) mySetStat = void (str key, TestResult result) {
		stats[key] = result;
	};
	
	void() myStartSession = void() {
		session = newSession(connections, log = log);
	};
	
	void() myCloseSession = void() {
		session.done();
	};
	
	void() myResetDatabases = void() {
		ses = newSession(connections, log = log);
		resetDatabasesInTest(sch, ses, log);
		ses.done();
	};
	ResultTable(Request req) myRunQuery = ResultTable(Request req) {
		ses = newSession(connections, log = log);
		result = runQueryInTest(req, sch, ses, log);
		ses.done();
		return result;
	};
	ResultTable(Request req, Schema s) myRunQueryForSchema = ResultTable(Request req, Schema s) {
		ses = newSession(connections, log = log);
		result = runQueryInTest(req, s, ses, log);
		ses.done();
		return result;
	};
	CommandResult(Request req) myRunUpdate = CommandResult(Request req) {
		ses = newSession(connections, log = log);
		result = runUpdateInTest(req, sch, ses, log);
		ses.done();
		return result;
	};
	CommandResult(Request req, Schema s) myRunUpdateForSchema = CommandResult(Request req, Schema s) {
		ses = newSession(connections, log = log);
		result = runUpdateInTest(req, s, ses, log);
		ses.done();
		return result;
	};
	CommandResult(Request req) myRunDDL = CommandResult(Request req) {
		ses = newSession(connections, log = log);
		result = runDDLInTest(req, sch, ses, log);
		ses.done();
		return result;
	};
	list[CommandResult](Request req, list[str] columnNames, list[list[str]] vs)
		myRunPreparedUpdate = list[CommandResult](Request req, list[str] columnNames, list[list[str]] vs) {
	    ses = newSession(connections, log = log); 
		result = runPreparedUpdateInTest(req, columnNames, vs, sch, ses, log);
		ses.done();
		return result;
	};
	Schema() myFetchSchema = Schema() {
		return fetchSchema(conn);
	};
	
	void() myPrintSchema = void() {
		printSchema(conn);
	};
	
	void (str testName, value actual, value expected)  myAssertEquals = void (str testName, value actual, value expected)  {
		stats = assertEquals(testName, actual, expected, stats);
	};
	
	void(str testName, tuple[list[str] sig, list[list[value]] vals] actual, tuple[list[str] sig, list[list[value]] vals] expected)
		myAssertResultEquals = void(str testName, tuple[list[str] sig, list[list[value]] vals] actual, tuple[list[str] sig, list[list[value]] vals] expected)  {
		stats = assertResultEquals(testName, actual, expected, stats);		
	};
	
	void (str testName, void() block) myAssertException = void (str testName, void() block) {
		stats = assertException(testName, block, stats);
	};
	
	PolystoreInstance proxy = <myResetStats, myGetStats, mySetStat,
		myResetDatabases, myStartSession, 
		myCloseSession, myRunQuery, myRunQueryForSchema,
		myRunUpdate, myRunUpdateForSchema, myRunDDL, myRunPreparedUpdate, 
		myFetchSchema, myPrintSchema,  myAssertEquals, myAssertResultEquals,
		myAssertException>;
		
	void(void(PolystoreInstance, bool), bool) myRunSetup = void(void(PolystoreInstance, bool) setupFun, bool doTests) {
		proxy.startSession();
		setupFun(proxy, doTests);
		proxy.closeSession();
	};
	
	void(void(PolystoreInstance)) myRunTest = void(void(PolystoreInstance proxy) t) {
		proxy.resetStats();
		runTest(proxy, setup, t, log = log);
	};
	
	void(list[void(PolystoreInstance)]) myRunTests = void(list[void(PolystoreInstance proxy)] ts) {
		proxy.resetStats();
		runTests(proxy, setup, ts, log = log);
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

CommandResult runDDLInTest(Request req, Schema s, Session session, Log log) {
	runDDL(req, s, session, log = log);
	return <-1, ()>;
}

CommandResult runUpdateInTest(Request req, Schema s, Session session, Log log) {
	return runUpdate(req, s, session, log = log);
}

list[CommandResult] runPreparedUpdateInTest(Request req, list[str] columnNames, list[list[str]] vs, Schema s, Session session, Log log) {
	return runPrepared(req, columnNames, vs, s, session, log = log);
}

ResultTable runQueryInTest(Request req, Schema s, Session session, Log log) {
	return runQuery(req, s, session, log = log);
}

void resetDatabasesInTest(Schema sch, Session session, Log log) {
	runSchema(sch, session, log = log);
}

void runTest(PolystoreInstance proxy, void(PolystoreInstance, bool) setup, void(PolystoreInstance) t, Log log = LOG, bool runTestsInSetup = false) {
	println("Running test: <t>");
	proxy.resetDatabases();
	setup(proxy, runTestsInSetup);
	try {
		t(proxy);		
	}
	catch e: {
		proxy.setStat("<t>", threw("<e>"));
		println (" <detailEmoji>: exception for `<t>`: <e>");
	}
}

str successEmoji = "\u001b[32m☀ \u001b[0m";
str failEmoji = "\u001b[31m☁ \u001b[0m";
str detailEmoji = "\u001b[34m☢ \u001b[0m";

Stats assertEquals(str testName, value actual, value expected, Stats stats) {
	if (actual != expected) {
	    stats[testName] = failed();
		println(" <failEmoji>: `<testName>` expected: <expected>, actual: <actual>");
	}
	else {
	    stats[testName] = success();
		println(" <successEmoji>: `<testName>`");
	}	
	return stats;
}

Stats assertResultEquals(str testName, tuple[list[str] sig, list[list[value]] vals] actual, tuple[list[str] sig, list[list[value]] vals] expected, Stats stats) {
  if (actual.sig != expected.sig) {
    stats[testName] = failed();
    println(" <failEmoji>: `<testName>` expected: <expected>, actual: <actual>");
  }
  else if (toSet(actual.vals) != toSet(expected.vals)) {
    stats[testName] = failed();
    println(" <failEmoji>: `<testName>` expected: <expected>, actual: <actual>");
  }
  else {
    stats[testName] = success();
	println(" <successEmoji>: `<testName>`");
  }
  return stats;
}

Stats assertException(str testName, void() block, Stats stats) {
	try {
		block();
		stats[testName] = failed();
   		println(" <failEmoji>: `<testName>` expected exception");
	} 
	catch e: {
		stats[testName] = success();
		println(" <successEmoji>: `<testName>`");
	}
	return stats;
}

void runTests(PolystoreInstance proxy, void(PolystoreInstance, bool) setup, list[void(PolystoreInstance)] tests, Log log = log ,  bool runTestsInSetup = false/*void(value v) {println(v);}*/) {
	
	proxy.resetStats();
	
	for (t <- tests) {
		runTest(proxy, setup, t, log = log, runTestsInSetup = runTestsInSetup);
	}
	
	Stats stats = proxy.getStats();
	
	println("# Summary");
	println("Number of tests: <size(tests)>");
	println("Number of asserts: <size([ k | str k <- stats, stats[k] in {failed(), success()} ])>");
	println("Number of success: <size([ k | str k <- stats, stats[k] == success() ])>");
	println("Number of failed: <size([ k | str k <- stats, stats[k] == failed() ])>");
	println("Number of throws: <size([ k | str k <- stats, stats[k] notin {failed(), success()} ])>");

}