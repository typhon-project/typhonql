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

tuple[int, map[str, str]] runUpdate(Request r, Schema s, map[str, Connection] connections) {
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
  			scr = request2script(r, s);
			println(scr);
			println(connections);
			Session session = newSession(connections);
			runScript(scr, session, s);
			return <-1, ()>;
  		}
  	}
    throw "Statement should have been provided";
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

ResultTable runQuery(str src, str xmiString, map[str, Conn] conns) {
  Model m = xmiString2Model(xmiString);
  Schema s = model2schema(m);
  Request req = [Request]src;
  map[str, Connection] connections = (() | it + (k : toConnection(tupl)) | k <- conns, tupl := conns[k]);
  return runQuery(req, s, connections);
}

lrel[int, map[str, str]] runPrepared(Request req, list[str] columnNames, list[list[str]] values, Schema s, map[str, Connection] conns) {
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
  	<n, uuids> = runUpdate(req_, s, conns);
  	rs += <n, uuids>;
  }
  return rs;
}

lrel[int, map[str, str]] runPrepared(str src, list[str] columnNames, list[list[str]] values, str xmiString, map[str, Conn] conns) {
  Model m = xmiString2Model(xmiString);
  Schema s = model2schema(m);
  map[str, Connection] connections = (() | it + (k : toConnection(tupl)) | k <- conns, tupl := conns[k]);
  return runPrepared([Request] src, columnNames, values, s, connections); 
}

Path buildPath(str selector, map[str, str] entityTypes) {
	list[str] parts = split(".", selector);
	str label = parts[0];
	ty = entityTypes[label];
	return <label, ty, parts[1..]>;
} 

void resetDatabase() {
	map[str, Connection] connections = (() | it + (k : toConnection(tupl)) | k <- conns, tupl := conns[k]);
	str modelStr = readHttpModel(|http://<HOST>:<PORT>|, "pablo", "antonio");
	Schema sch = loadSchemaFromXMI(modelStr);
	runSchema("http://<HOST>:<PORT>", sch, connections);
}


