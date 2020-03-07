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
import String;

void runUpdate(Request r, Schema s, map[str, Connection] connections) {
	scr = request2script(r, s);
	println(scr);
	println(connections);
	Session session = newSession(connections);
	runScript(scr, session, s);
}

str runQuery(Request r, str entryDatabase, Schema sch, map[str, Connection] connections) {
	if ((Request) `from <{Binding ","}+ bs> select <{Result ","}+ selected> <Where? where> <GroupBy? groupBy> <OrderBy? orderBy>` := r) {
		map[str, str] types = (() | it + ("<var>":"<entity>") | (Binding) `<EId entity> <VId var>` <- bs);
		list[str] columnNames = ["<parts[0]>.<ty>.<intercalate(".", parts[1..])>" | s <- selected, list[str] parts := split(".", "<s>"), ty := types[parts[0]]];
		println(selected);
		println(columnNames);
		scr = request2script(r, sch);
		println(scr);
		println(connections);
		Session session = newSession(connections);
		runScript(scr, session, sch);
		
		
		// TODO {<column, "DUMMY">} => [column]
		str result = session.read(entryDatabase, {<column, "DUMMY"> | column <- columnNames}, {}); 
		return result;
	}
	else
		throw "Expected query, given statement";
}

