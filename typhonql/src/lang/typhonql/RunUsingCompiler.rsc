module lang::typhonql::RunUsingCompiler


import lang::typhonml::Util;
import lang::typhonml::TyphonML;

import lang::typhonql::WorkingSet;
import lang::typhonql::Native;
import lang::typhonql::Partition;
import lang::typhonql::TDBC;
import lang::typhonql::Eval;
import lang::typhonql::Closure;
import lang::typhonql::Session;
import lang::typhonql::Request2Script;
import lang::typhonql::Script;

import lang::typhonql::util::Log;

import lang::typhonml::XMIReader;

import IO;
import Set;
import List;
import util::Maybe;
import String;

tuple[int, map[str, str]] runUpdate(Request r, Schema s, map[str, Connection] connections) {
	scr = request2script(r, s);
	println(scr);
	println(connections);
	Session session = newSession(connections);
	runScript(scr, session, s);
	return <-1, ()>;
}


ResultTable runQuery(Request r, Schema sch, map[str, Connection] connections) {
	if ((Request) `from <{Binding ","}+ bs> select <{Result ","}+ selected> <Where? where> <GroupBy? groupBy> <OrderBy? orderBy>` := r) {
		map[str, str] types = (() | it + ("<var>":"<entity>") | (Binding) `<EId entity> <VId var>` <- bs);
		list[Path] paths = [buildPath("<s>", types)| s <- selected];
		scr = request2script(r, sch);
		str entryDatabase = [r | step(str r, _, _) <- scr.steps][-1];
		println(scr);
		println(connections);
		Session session = newSession(connections);
		runScript(scr, session, sch);
		// TODO {<column, "DUMMY">} => [column]
		ResultTable result = session.read(entryDatabase, paths); 
		return result;
	}
	else
		throw "Expected query, given statement";
}

tuple[int, map[str, str]] runUpdate(str src, str xmiString, map[str, Conn] conns) {
  Model m = xmiString2Model(xmiString);
  Schema s = model2schema(m);
  Request req = [Request]src;
  map[str, Connection] connections = (() | it + (k : toConnection(tupl)) | k <- conns, tupl := conns[k]);
  return runUpdate(req, s, connections);
}


ResultTable runQuery(str src, str xmiString, map[str, Conn] conns) {
  Model m = xmiString2Model(xmiString);
  Schema s = model2schema(m);
  Request req = [Request]src;
  map[str, Connection] connections = (() | it + (k : toConnection(tupl)) | k <- conns, tupl := conns[k]);
  return runQuery(req, s, connections);
}

Connection toConnection(<str dbType, str host, int port, str user, str password>) {
	switch (dbType) {
		case "sql":
			return sqlConnection(host, port, user, password);
		case "mongo":
			return mongoConnection(host, port, user, password);
		default:
			throw "DB type <dbType> unknown";
	}
}

Path buildPath(str selector, map[str, str] entityTypes) {
	list[str] parts = split(".", selector);
	str label = parts[0];
	ty = entityTypes[label];
	return <label, ty, parts[1..]>;
} 

