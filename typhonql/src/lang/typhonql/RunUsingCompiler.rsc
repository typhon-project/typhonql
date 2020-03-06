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
import lang::typhonql::ResultTable;

import IO;
import Set;
import List;
import util::Maybe;

void runUpdate(Request r, Schema s, map[str, Connection] connections) {
	scr = request2script(r, s);
	println(scr);
	println(connections);
	Session session = newSession(connections);
	runScript(scr, session, s);
}

ResultTable runQuery(Request r, Schema s, map[str, Connection] connections) {
	scr = request2script(r, s);
	println(scr);
	println(connections);
	Session session = newSession(connections);
	runScript(scr, session, s);
	return <[], []>;
}

