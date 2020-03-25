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
import lang::typhonml::XMIReader;

import lang::typhonql::util::Log;

import IO;
import Set;
import List;
import util::Maybe;
import String;

void runDDL(Request r, Schema s, map[str, Connection] connections, Log log = noLog) {
	if ((Request) `<Statement stmt>` := r) {
		// TODO This is needed because we do not have an explicit way to distinguish
		// DDL updates from DML updates. Perhaps we should consider it
  		if (isDDL(stmt)) {
  			run(r, s, connections, log = log);
  		}
  		else {
  			throw "DDL statement should have been provided";
  		}
  	}
  	else {
  		throw "Statement should have been provided";
  	}
}

tuple[int, map[str, str]] runUpdate(Request r, Schema s, map[str, Connection] connections, Log log = noLog) {
	Session session = newSession(connections, log = log);
	return runUpdate(r, s, session, log = log);
}

tuple[int, map[str, str]] runUpdate(Request r, Schema s, Session session, Log log = noLog) {
	if ((Request) `<Statement stmt>` := r) {
		// TODO This is needed because we do not have an explicit way to distinguish
		// DDL updates from DML updates. Perhaps we should consider it
  		if (!isDDL(stmt)) {
  			scr = request2script(r, s, log = log);
			log("[runUpdate-DDL] Script: <scr>");
			res = runScript(scr, session, s);
			if (res != "")
				return <-1, ("result" : res)>;
			else
				return <-1, ()>;
  		}
  		else {
  			throw "DML statement should have been provided";
  		}
  	}
    throw "Statement should have been provided";
}

value runQueryAndGetJava(Request r, Schema sch, map[str, Connection] connections, Log log = noLog) {
	Session session = newSession(connections, log = log);
	return runQueryAndGetJava(r, sch, session, log = log);
}

void runScriptForQuery(Request r, Schema sch, Session session, Log log = noLog) {
	if ((Request) `from <{Binding ","}+ bs> select <{Result ","}+ selected> <Where? where> <GroupBy? groupBy> <OrderBy? orderBy>` := r) {
		scr = request2script(r, sch, log = log);
		log("[runScriptForQuery] Script: <scr>");
		runScript(scr, session, sch);
	}
	else
		throw "Expected query, given statement";
}

value runQueryAndGetJava(Request r, Schema sch, Session session, Log log = noLog) {
	runScriptForQuery(r, sch, session, log = log);
	return session.getJavaResult();
}

ResultTable runQuery(Request r, Schema sch, Session session, Log log = noLog) {
	runScriptForQuery(r, sch, session, log = log);
	return session.getResult();
}

ResultTable runQuery(Request r, Schema sch, map[str, Connection] connections, Log log = noLog) {
	Session session = newSession(connections, log = log);
	return runQuery(r, sch, session, log = log);
}

ResultTable runQuery(Request r, Schema sch, Session session, Log log = noLog) {
	if ((Request) `from <{Binding ","}+ bs> select <{Result ","}+ selected> <Where? where> <GroupBy? groupBy> <OrderBy? orderBy>` := r) {
		map[str, str] types = (() | it + ("<var>":"<entity>") | (Binding) `<EId entity> <VId var>` <- bs);
		list[Path] paths = [buildPath("<s>", types)| s <- selected];
		scr = request2script(r, sch, log = log);
		str entryDatabase = [r | step(str r, _, _) <- scr.steps][-1];
		log("[runQuery] Script: <scr>");
		runScript(scr, session, sch);
		// TODO {<column, "DUMMY">} => [column]
		ResultTable result = session.read(entryDatabase, paths); 
		return result;
	}
	else
		throw "Expected query, given statement";
}

tuple[int, map[str, str]] runUpdate(str src, str xmiString, map[str, Connection] connections, Log log = noLog) {
  Session session = newSession(connections, log = log);
  return runUpdate(src, xmiString, session, log = log);
}

tuple[int, map[str, str]] runUpdate(str src, str xmiString, Session session, Log log = noLog) {
  Model m = xmiString2Model(xmiString);
  Schema s = model2schema(m);
  Request req = [Request]src;
  return runUpdate(req, s, session, log = log);
}

ResultTable runQuery(str src, str xmiString, map[str, Connection] connections, Log log = noLog) {
  Session session = newSession(connections, log = log);
  return runQuery(src, xmiString, session, log = log);
}

ResultTable runQuery(str src, str xmiString, Session session, Log log = noLog) {
  Model m = xmiString2Model(xmiString);
  Schema s = model2schema(m);
  Request req = [Request]src;
  return runQuery(req, s, session, log = log);
}

value runQueryAndGetJava(str src, str xmiString, map[str, Connection] connections, Log log = noLog) {
  Session session = newSession(connections, log = log);
  return runQueryAndGetJava(src, xmiString, session, log = log);
}

value runQueryAndGetJava(str src, str xmiString, Session session, Log log = noLog) {
  Model m = xmiString2Model(xmiString);
  Schema s = model2schema(m);
  Request req = [Request]src;
  return runQueryAndGetJava(req, s, session, log = log);
}

lrel[int, map[str, str]] runPrepared(Request req, list[str] columnNames, list[list[str]] values, Schema s, map[str, Connection] connections, Log log = noLog) {
	Session session = newSession(connections, log = log);
	return runPrepared(req, columnNames, values, s, session, log = log);
}

lrel[int, map[str, str]] runPrepared(Request req, list[str] columnNames, list[list[str]] values, Schema s, Session session, Log log = noLog) {
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
  	<n, uuids> = runUpdate(req_, s, session, log = log);
  	rs += <n, uuids>;
  }
  return rs;
}

lrel[int, map[str, str]] runPrepared(str src, list[str] columnNames, list[list[str]] values, str xmiString, Session session, Log log = noLog) {
 	Model m = xmiString2Model(xmiString);
  	Schema s = model2schema(m);	
	return runPrepared([Request] src, columnNames, values, s, session, log = log);
}

lrel[int, map[str, str]] runPrepared(str src, list[str] columnNames, list[list[str]] values, str xmiString, map[str, Connection] connections, Log log = noLog) {
 	Session session = newSession(connections, log = log);
 	return runPrepared(src, columnNames, values, xmiString, session, log = log);
}

void runDDL(str src,  str xmiString, map[str, Connection] connections, Log log = noLog) {
	Model m = xmiString2Model(xmiString);
  	Schema s = model2schema(m);	
	runDDL([Request] src, s, connections, log = log);
}

Path buildPath(str selector, map[str, str] entityTypes) {
	list[str] parts = split(".", selector);
	str label = parts[0];
	ty = entityTypes[label];
	return <label, ty, parts[1..]>;
}

