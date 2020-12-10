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

module lang::typhonql::RunUsingCompiler


import lang::typhonml::Util;
import lang::typhonml::TyphonML;

import lang::typhonql::TDBC;
import lang::typhonql::Session;
import lang::typhonql::Request2Script;
import lang::typhonql::Schema2Script;
import lang::typhonql::Script;
import lang::typhonql::check::Checker;
import lang::typhonml::XMIReader;
import ParseTree;

import lang::typhonql::util::Log;
import util::Benchmark;
import Exception;
import util::Memo;

import IO;
import Set;
import List;
import util::Maybe;
import String;

bool bench = false;

void runDDL(Request r, Schema s, Session session, Log log = noLog) {
	if ((Request) `<Statement stmt>` := r) {
		// TODO This is needed because we do not have an explicit way to distinguish
		// DDL updates from DML updates. Perhaps we should consider it
  		if (isDDL(stmt)) {
  			runUpdate(r, s, s, session, log = log);
  		}
  		else {
  			throw "DDL statement should have been provided";
  		}
  	}
  	else {
  		throw "Statement should have been provided";
  	}
}

str validateQuery(Tree t, Schema s, Log log) {
    m = checkQLTree(t, s);
    errorMessage = "";
    for (error(msg, at) <- m.messages) {
        if (errorMessage != "") {
            errorMessage += " & ";
        }
        errorMessage += "<msg> at offset <at.offset>";
    }
    if (errorMessage != "") {
        throw errorMessage;
    }
    str warnMessage = "";
    for (warning(msg, at) <- m.messages) {
        if (warnMessage != "") {
            warnMessage += " & ";
        }
        warnMessage += "<msg> at offset <at.offset>";
    }
    return warnMessage;
}

list[str] runUpdate(Request r, Schema s, Schema sPlain, Session session, bool runChecker = true, Log log = noLog,
	int argumentsSize = -1) {
	if ((Request) `<Statement stmt>` := r) {
		// TODO This is needed because we do not have an explicit way to distinguish
		// DDL updates from DML updates. Perhaps we should consider it
  		if (!isDDL(stmt)) {
            startScript = getNanoTime();
            warnings = "";
            if (runChecker) {
                warnings = validateQuery(r, sPlain, log);
                if (warnings != "") {
                    session.report(warnings);
                }
            }
  			scr = request2script(r, s, log = log);
			log("[runUpdate] Script: <scr>");
            endScript = getNanoTime();
			list[str] res = runScript(scr, session, s);
			
            endExecute = getNanoTime();
            if (bench) {
                println("BENCH: request, <endScript - startScript>, <endExecute - endScript>");
            }
			return res + (warnings != "" ? [warnings] : []);
  		}
  		else {
  			scr = request2script(r, s, log = log);
			log("[runUpdate-DDL] Script: <scr>");
			list[str] res = runScript(scr, session, s);
			return res;
  		}
  	}
    throw "Statement should have been provided";
}

void runScriptForQuery(Request r, Schema sch, Schema schPlain, Session session,bool runChecker = true, Log log = noLog) {
	if ((Request) `from <{Binding ","}+ bs> select <{Result ","}+ selected> <Where? where> <Agg* aggs>` := r) {
        startScript = getNanoTime();
        if (runChecker) {
            warnings = validateQuery(r, schPlain, log);
            if (warnings != "") {
                session.report(warnings);
            }
        }
		scr = request2script(r, sch, log = log);
        endScript = getNanoTime();
		log("[runScriptForQuery] Script: <scr>");
		runScript(scr, session, sch);
        endExecute = getNanoTime();
        if (bench) {
            println("BENCH: query, <endScript - startScript>, <endExecute - endScript>");
        }
	}
	else
		throw "Expected query, given statement";
}

value runQueryAndGetJava(Request r, Schema sch, Schema schPlain, Session session, bool runChecker = true, Log log = noLog) {
	runScriptForQuery(r, sch, schPlain, session, runChecker = runChecker, log = log);
	return session.getJavaResult();
}

value runGetEntity(str entity, str uuid, Schema sch, Schema schPlain, Session session, Log log = noLog) {
	list[str] attributes = [att | <entity, att, _> <- sch.attrs];
	// TODO put alias to the columns
	Request r = parseRequest("from <entity> e select
	                      ' <intercalate(", ", ["e.<a>" | a <- attributes])> 
	                      'where e.@id == #<uuid>");	
	runScriptForQuery(r, sch, schPlain, session, log = log);
	return session.getJavaResult();
}

Where enrichWhere(str var, w:(Where) `where <{Expr ","}+ clauses>`) =
	visit (w) {
		case (Expr) `<VId x>` => [Expr] "<var>.<x>"
	};

value listEntities(str entity, str whereClause, str limit, str sortBy, Schema sch, Schema schPlain, Session session, Log log = noLog) {
	list[str] attributes = [att | <entity, att, _> <- sch.attrs];
	Request r = parseRequest("from <entity> e select
	                      ' <intercalate(", ", ["e.<a>" | a <- attributes])> 
	                      '<!isEmpty(whereClause)?"where <whereClause>":"">
	                      '<!isEmpty(sortBy)?"order <sortBy>":"">");	
	r = visit (r) {
		case Where w => enrichWhere("e", w) 
	};	                      
	                      
	runScriptForQuery(r, sch, schPlain, session, log = log);
	return session.getJavaResult();
}

ResultTable runQuery(Request r, Schema sch, Schema schPlain, Session session,bool runChecker = true, Log log = noLog) {
	runScriptForQuery(r, sch, schPlain, session, runChecker = runChecker, log = log);
	return session.getResult();
}


void runSchema(Schema sch, Session session, Log log = noLog) {
    startScript = getNanoTime();
	scr = schema2script(sch, log = log);
    endScript = getNanoTime();
	runScript(scr, session, sch);
    endExecute = getNanoTime();
    if (bench) {
        println("BENCH: schema, <endScript - startScript>, <endExecute - endScript>");
    }
}

list[str] runUpdate(str src, str xmiString, map[str, Connection] connections, bool runChecker = true,Log log = noLog) {
  Session session = newSession(connections);
  return runUpdate(src, xmiString, session, runChecker = runChecker, log = log);
}

list[str] runUpdate(str src, str xmiString, Session session, bool runChecker = true, Log log = noLog) {
  Schema s = loadSchemaFromXMI(xmiString, normalize = true);
  Schema sPlain = loadSchemaFromXMI(xmiString, normalize = false);
  Request req = parseRequest(src);
  return runUpdate(req, s, sPlain, session, runChecker = runChecker, log = log);
}

ResultTable runQuery(str src, str xmiString, map[str, Connection] connections, bool runChecker = true,Log log = noLog) {
  Session session = newSession(connections);
  return runQuery(src, xmiString, session, runChecker = runChecker, log = log);
}

ResultTable runQuery(str src, str xmiString, Session session, bool runChecker = true, Log log = noLog) {
  Schema s = loadSchemaFromXMI(xmiString, normalize = true);
  Schema sPlain = loadSchemaFromXMI(xmiString, normalize = false);
  Request req = parseRequest(src);
  return runQuery(req, s, sPlain, session, runChecker = runChecker, log = log);
}

value runQueryAndGetJava(str src, str xmiString, map[str, Connection] connections, Log log = noLog) {
  Session session = newSession(connections);
  return runQueryAndGetJava(src, xmiString, session, log = log);
}

value runQueryAndGetJava(str src, str xmiString, Session session, Log log = noLog) {
  Schema s = loadSchemaFromXMI(xmiString, normalize = true);
  Schema sPlain = loadSchemaFromXMI(xmiString, normalize = false);
  Request req = parseRequest(src);
  return runQueryAndGetJava(req, s, sPlain, session, log = log);
}

value runGetEntity(str entity, str uuid, str xmiString, map[str, Connection] connections, Log log = noLog) {
  Session session = newSession(connections);
  return runGetEntity(entity, uuid, xmiString, session, log = log);
}

value runGetEntity(str entity, str uuid, str xmiString, Session session, Log log = noLog) {
  Schema s = loadSchemaFromXMI(xmiString, normalize = true);
  Schema sPlain = loadSchemaFromXMI(xmiString, normalize = false);
  return runGetEntity(entity, uuid, s, sPlain, session, log = log);
}

value listEntities(str entity, str whereClause, str limit, str sortBy, str xmiString, Session session, Log log = noLog) {
  Schema s = loadSchemaFromXMI(xmiString, normalize = true);
  Schema sPlain = loadSchemaFromXMI(xmiString, normalize = false);
  return listEntities(entity, whereClause, limit, sortBy, s, sPlain, session, log = log);
}

@memo={maximumSize(50), expireAfter(hours=1)}
Request parseRequest(str src) {
    try {
        return parse(#Request, src, |external:///|);
    } catch ParseError(loc of): {
        throw "Error parsing:\n<src>\nposition: <of.begin> -- <of.end>";
    }
}

void runDDL(str src,  str xmiString, Session session, Log log = noLog) {
	Model m = xmiString2Model(xmiString);
  	Schema s = model2schema(m);	
	runDDL(parseRequest(src), s, session, log = log);
}

void runDDL(str src,  str xmiString, map[str, Connection] connections, Log log = noLog) {
	Session session = newSession(connections);
	runDDL(src, xmiString, session, log = log);
}

void runSchema(str xmiString, Session session, Log log = noLog) {
	Model m = xmiString2Model(xmiString);
  	Schema s = model2schema(m);	
	runSchema(s, session, log = log);
}

void runSchema(str xmiString, map[str, Connection] connections, Log log = noLog) {
	Session session = newSession(connections);
	runSchema(xmiString, session, log = log);
}

Path buildPath(str selector, map[str, str] entityTypes) {
	list[str] parts = split(".", selector);
	str label = parts[0];
	ty = entityTypes[label];
	return <label, ty, parts[1..]>;
}
