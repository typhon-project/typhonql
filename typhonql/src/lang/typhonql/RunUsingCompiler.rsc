module lang::typhonql::RunUsingCompiler


import lang::typhonml::Util;
import lang::typhonml::TyphonML;

import lang::typhonql::WorkingSet;
import lang::typhonql::Native;
import lang::typhonql::Partition;
import lang::typhonql::TDBC;
import lang::typhonql::DDL;
import lang::typhonql::Eval;
import lang::typhonql::Closure;
import lang::typhonql::Session;
import lang::typhonql::Request2Script;
import lang::typhonql::Script;
// TODO for now only for the DDL. Modularize better
import lang::typhonql::Run;
import lang::typhonql::util::Log;
import lang::typhonml::XMIReader;

import IO;
import Set;
import List;
import util::Maybe;
import String;

tuple[int, map[str, str]] runDDL(Request r, Schema s, map[str, Connection] connections) {
	if ((Request) `<Statement stmt>` := r) {
		// TODO This is needed because we do not have an explicit way to distinguish
		// DDL updates from DML updates. Perhaps we should consider it
  		if (isDDL(stmt)) {
  			if (tuple[int, map[str, str]]  t := run(r, s, connections)) {
  				return t;
  			}
  			else
  				throw "Dynamic type error for DDL execution operation";
  			
  		}
  		else {
  			throw "DDL statement should have been provided";
  		}
  	}
    throw "Statement should have been provided";
}


tuple[int, map[str, str]] runUpdate(Request r, Schema s, map[str, Connection] connections) {
	Session session = newSession(connections);
	return runUpdate(r, s, session);
}

tuple[int, map[str, str]] runUpdate(Request r, Schema s, Session session) {
	if ((Request) `<Statement stmt>` := r) {
		// TODO This is needed because we do not have an explicit way to distinguish
		// DDL updates from DML updates. Perhaps we should consider it
  		if (!isDDL(stmt)) {
  			scr = request2script(r, s);
			println(scr);
			runScript(scr, session, s);
			return <-1, ()>;
  		}
  		else {
  			throw "DML statement should have been provided";
  		}
  	}
    throw "Statement should have been provided";
}

void runQueryAndStore(Request r, Schema sch, map[str, Connection] connections) {
	Session session = newSession(connections);
	return runQueryAndStore(r, sch, session);
}

tuple[str entryDatabase, list[Path] paths] runScriptForQuery(Request r, Schema sch, Session session) {
	if ((Request) `from <{Binding ","}+ bs> select <{Result ","}+ selected> <Where? where> <GroupBy? groupBy> <OrderBy? orderBy>` := r) {
		scr = request2script(r, sch);
		println(scr);
		runScript(scr, session, sch);
		map[str, str] types = (() | it + ("<var>":"<entity>") | (Binding) `<EId entity> <VId var>` <- bs);
		list[Path] paths = [buildPath("<s>", types)| s <- selected];
		str entryDatabase = [r | step(str r, _, _) <- scr.steps][-1];
		return <entryDatabase, paths>;
	}
	else
		throw "Expected query, given statement";
}

void runQueryAndStore(Request r, Schema sch, Session session) {
	<entryDatabase, paths> = runScriptForQuery(r, sch, session);
	session.readAndStore(entryDatabase, paths); 
}

ResultTable runQuery(Request r, Schema sch, Session session) {
	<entryDatabase, paths> = runScriptForQuery(r, sch, session);
	ResultTable result = session.read(entryDatabase, paths); 
	return result;
}

ResultTable runQuery(Request r, Schema sch, map[str, Connection] connections) {
	Session session = newSession(connections);
	return runQuery(r, sch, session);
}

ResultTable runQuery(Request r, Schema sch, Session session) {
	if ((Request) `from <{Binding ","}+ bs> select <{Result ","}+ selected> <Where? where> <GroupBy? groupBy> <OrderBy? orderBy>` := r) {
		map[str, str] types = (() | it + ("<var>":"<entity>") | (Binding) `<EId entity> <VId var>` <- bs);
		list[Path] paths = [buildPath("<s>", types)| s <- selected];
		scr = request2script(r, sch);
		str entryDatabase = [r | step(str r, _, _) <- scr.steps][-1];
		println(scr);
		runScript(scr, session, sch);
		// TODO {<column, "DUMMY">} => [column]
		ResultTable result = session.read(entryDatabase, paths); 
		return result;
	}
	else
		throw "Expected query, given statement";
}

tuple[int, map[str, str]] runUpdate(str src, str xmiString, map[str, Connection] connections) {
  Session session = newSession(connections);
  return runUpdate(src, xmiString, session);
}

tuple[int, map[str, str]] runUpdate(str src, str xmiString, Session session) {
  Model m = xmiString2Model(xmiString);
  Schema s = model2schema(m);
  Request req = [Request]src;
  return runUpdate(req, s, session);
}

ResultTable runQuery(str src, str xmiString, map[str, Connection] connections) {
  Session session = newSession(connections);
  return runQuery(src, xmiString, session);
}

ResultTable runQuery(str src, str xmiString, Session session) {
  Model m = xmiString2Model(xmiString);
  Schema s = model2schema(m);
  Request req = [Request]src;
  return runQuery(req, s, session);
}

void runQueryAndStore(str src, str xmiString, map[str, Connection] connections) {
  Session session = newSession(connections);
  runQueryAndStore(src, xmiString, session);
}

void runQueryAndStore(str src, str xmiString, Session session) {
  Model m = xmiString2Model(xmiString);
  Schema s = model2schema(m);
  Request req = [Request]src;
  runQueryAndStore(req, s, session);
}

lrel[int, map[str, str]] runPrepared(Request req, list[str] columnNames, list[list[str]] values, Schema s, map[str, Connection] conns) {
	Session session = newSession(connections);
	return runPrepared(req, columnNames, values, s, session);
}

lrel[int, map[str, str]] runPrepared(Request req, list[str] columnNames, list[list[str]] values, Schema s, Session session) {
  lrel[int, map[str, str]] rs = [];
  int numberOfVars = size(columnNames);
  for (list[str] vs <- values) {
  	map[str, str] labeled = (() | it + (columnNames[i] : vs[i]) | i <-[0 .. numberOfVars]);
  	int i = 0;
  	Request req_ = visit(req) {
  		case (Expr) `<PlaceHolder ph>`: {
  			valStr = labeled["<ph.name>"];
  			e = [Expr] valStr; 
  			insert e;
  		}
  	};
  	println(req_);
  	<n, uuids> = runUpdate(req_, s, session);
  	rs += <n, uuids>;
  }
  return rs;
}

lrel[int, map[str, str]] runPrepared(str src, list[str] columnNames, list[list[str]] values, str xmiString, Session session) {
 	Model m = xmiString2Model(xmiString);
  	Schema s = model2schema(m);	
	return runPrepared([Request] src, columnNames, values, s, session);
}

lrel[int, map[str, str]] runPrepared(str src, list[str] columnNames, list[list[str]] values, str xmiString, map[str, Connection] connections) {
 	Session session = newSession(connections);
 	return runPrepared(src, columnNames, values, xmiString, session);
}

Path buildPath(str selector, map[str, str] entityTypes) {
	list[str] parts = split(".", selector);
	str label = parts[0];
	ty = entityTypes[label];
	return <label, ty, parts[1..]>;
}

