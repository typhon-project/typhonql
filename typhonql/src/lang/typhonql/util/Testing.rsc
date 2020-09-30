/********************************************************************************
* Copyright (c) 2018-2020 CWI & Swat.engineering 
*
* This program and the accompanying materials are made available under the
* terms of the Eclipse Public License 2.0 which is available at
* http://www.eclipse.org/legal/epl-2.0.
*
* This Source Code may also be made available under the following Secondary
* Licenses when the conditions for such availability set forth in the Eclipse
* Public License, v. 2.0 are satisfied: GNU General Public License, version 2
* with the GNU Classpath Exception which is
* available at https://www.gnu.org/software/classpath/license.html.
*
* SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0
********************************************************************************/

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
import lang::typhonql::check::Checker;

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
		list[str](Request req) runUpdate,
		list[str](Request req, map[str,str] blobMap) runUpdateWithBlobs,
		list[str](Request req, Schema s) runUpdateForSchema,
		list[str](Request req) runDDL,
		list[str](Request req, Schema s) runDDLForSchema,
		list[str](Request req, list[str] columnNames, list[str] columnTypes, list[list[str]] vs)
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
		void(void(PolystoreInstance proxy), bool) runTest,
		void(list[void(PolystoreInstance proxy)], bool) runTests,
		Schema() fetchSchema];
		
TestExecuter initTest(void(PolystoreInstance, bool) setup, str host, str port, str user, str password, Log log = NO_LOG()) {
	Conn conn = <host, port, user, password>;
	Schema sch = fetchSchema(conn);
	Schema schPlain = fetchNonNormalizedModel(conn);
	CheckerMLSchema checkSch = convertModel(schPlain);
	map[str, Connection] connections =  readConnectionsInfo(conn.host, toInt(conn.port), conn.user, conn.password);
	Session session;
	
	void checkRequest(Request r, Schema schm = sch) {
	   try {
           model = checkQLTree(r, (schm == sch) ? checkSch : converModel(schm));
           for (m <- model.messages) {
               println("  <failEmoji> checker: <m>");
           }
	   } catch value v: {
	       println("Checker crashed with: <v>");
	   }
	};
	
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
		session = newSession(connections);
	};
	
	void() myCloseSession = void() {
		session.done();
	};
	
	void() myResetDatabases = void() {
		ses = newSession(connections);
		resetDatabasesInTest(sch, ses, log);
		ses.done();
	};
	ResultTable(Request req) myRunQuery = ResultTable(Request req) {
        checkRequest(req);
		ses = newSession(connections);
		result = runQueryInTest(req, sch, schPlain, ses, log);
		ses.done();
		return result;
	};
	ResultTable(Request req, Schema s) myRunQueryForSchema = ResultTable(Request req, Schema s) {
        checkRequest(req, schm = s);
		ses = newSession(connections);
		result = runQueryInTest(req, s, s, ses, log);
		ses.done();
		return result;
	};
	list[str](Request req) myRunUpdate = list[str](Request req) {
        checkRequest(req);
		ses = newSession(connections);
		result = runUpdateInTest(req, sch, schPlain, ses, log);
		ses.done();
		return result;
	};

	myRunUpdateBlobs = list[str](Request req, map[str,str] blobMap) {
        checkRequest(req);
		ses = newSession(connections, blobMap = blobMap);
		result = runUpdateInTest(req, sch, schPlain, ses, log);
		ses.done();
		return result;
	};
	list[str](Request req, Schema s) myRunUpdateForSchema = list[str](Request req, Schema s) {
        checkRequest(req, schm = s);
		ses = newSession(connections);
		result = runUpdateInTest(req, s, s, ses, log);
		ses.done();
		return result;
	};
	list[str](Request req) myRunDDL = list[str](Request req) {
        checkRequest(req);
		ses = newSession(connections);
		result = runDDLInTest(req, sch, ses, log);
		ses.done();
		return result;
	};
	list[str](Request req, Schema s) myRunDDLForSchema = list[str](Request req, Schema s) {
        checkRequest(req);
		ses = newSession(connections);
		result = runDDLInTest(req, s, ses, log);
		ses.done();
		return result;
	};
	list[str](Request req, list[str] columnNames, list[str] columnTypes, list[list[str]] vs) 
		myRunPreparedUpdate = list[str](Request req, list[str] columnNames, list[str] columnTypes, list[list[str]] vs) {
        checkRequest(req);
	    ses = newSessionWithArguments(connections, columnNames, columnTypes, vs); 
		result = runUpdateInTest(req, sch, schPlain, ses, log);
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
		myRunUpdate, myRunUpdateBlobs, myRunUpdateForSchema, myRunDDL, myRunDDLForSchema, myRunPreparedUpdate, 
		myFetchSchema, myPrintSchema,  myAssertEquals, myAssertResultEquals,
		myAssertException>;
		
	void(void(PolystoreInstance, bool), bool) myRunSetup = void(void(PolystoreInstance, bool) setupFun, bool doTests) {
		proxy.resetDatabases();
		proxy.startSession();
		setupFun(proxy, doTests);
		proxy.closeSession();
	};
	
	myRunTest = void(void(PolystoreInstance proxy) t, bool runTestsInSetup) {
		proxy.resetStats();
		runTest(proxy, setup, t, log = log, runTestsInSetup = runTestsInSetup);
	};
	
	myRunTests = void(list[void(PolystoreInstance proxy)] ts, bool runTestsInSetup) {
		proxy.resetStats();
		runTests(proxy, setup, ts, log = log, runTestsInSetup = runTestsInSetup);
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
Schema fetchNonNormalizedModel(Conn c)
    = loadSchemaFromXMI(readHttpModel(|http://<c.host>:<c.port>|, c.user, c.password), normalize = false);

list[str] runDDLInTest(Request req, Schema s, Session session, Log log) {
	runDDL(req, s, session, log = log);
	return <-1, ()>;
}

list[str] runUpdateInTest(Request req, Schema s, Schema sPlain, Session session, Log log) {
	return runUpdate(req, s, sPlain, session, log = log);
}

ResultTable runQueryInTest(Request req, Schema s, Schema sPlain, Session session, Log log) {
	return runQuery(req, s, sPlain, session, log = log);
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
