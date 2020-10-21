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

module lang::typhonql::Schema2Script

import IO;
import ValueIO;
import List;
import String;
import util::Maybe;

import lang::typhonml::Util;
import lang::typhonql::Script;
import lang::typhonql::Session;
import lang::typhonql::relational::SchemaToSQL;
import lang::typhonql::cassandra::Schema2CQL;
import lang::typhonql::cassandra::CQL;
import lang::typhonql::cassandra::CQL2Text;

import lang::typhonql::neo4j::Neo;
import lang::typhonql::neo4j::Neo2Text;

import lang::typhonql::util::Log;

import lang::typhonql::relational::SQL;
import lang::typhonql::relational::SQL2Text;

Script schema2script(Schema s, Log log = noLog) {
	list[Step] steps = [];
	for (Place p <- s.placement<0>) {
    	log("[schema2script] generating script for <p>");
    	steps += place2script(p, s, log = log);
  	}
  	steps+= finish();
  	return script(steps);
}

list[Step] place2script(p:<cassandra(), str db>, Schema s, Log log = noLog) {
  return [
    step(db, cassandra(cExecuteGlobalStatement(db, "DROP KEYSPACE IF EXISTS \"<db>\";")), ()),
    
    // not sure what to do here with  replication etc.
    step(db, cassandra(cExecuteGlobalStatement(db, "CREATE KEYSPACE \"<db>\" WITH replication = {\'class\': \'SimpleStrategy\', \'replication_factor\' : 1};")), ()),
    step(db, cassandra(cExecuteGlobalStatement(db, "USE \"<db>\";")), ())
  ] + [ step(db, cassandra(cExecuteGlobalStatement(db, pp(stmt))), ()) 
          | CQLStat stmt <-  schema2cql(s, p, s.placement[p]) ];
}

list[Step] place2script(p: <sql(), str db>, Schema s, Log log = noLog) {
  list[Step] steps = [];
  steps += [step(db, sql(executeGlobalStatement(db, "DROP DATABASE IF EXISTS `<db>`")), ())];
  steps += [step(db, sql(executeGlobalStatement(db, "CREATE DATABASE `<db>` 
					'   DEFAULT CHARACTER SET utf8mb4 
					'   DEFAULT COLLATE utf8mb4_unicode_ci")), ())];
  list[SQLStat] stats = schema2sql(s, p, s.placement[p], doForeignKeys = true);
  for (SQLStat stat <- stats) {
    log("[schema2script/sql/<db>] Adding to the script: <pp(stat)>");
    steps += [step(db, sql(executeStatement(db, pp(stat))), ())];     
  }
  return steps;
}

list[Step] place2script(p:<mongodb(), str db>, Schema s, Log log = noLog) {
  list[Step] steps = [step(db, mongo(dropDatabase(db)), ())];

  for (str entity <- s.placement[p]) {
    log("[RUN-schema/mongodb/<db>] creating collection <entity>");
    steps += [step(db, mongo(dropCollection(db, entity)), ())];
    steps += [step(db, mongo(createCollection(db, entity)), ())];


    // add geo indexes
    steps += [step(db, mongo(createIndex(db, entity, "{\"<attr>\": \"2dsphere\"}")), ()) 
        | <str attr, str typ> <- s.attrs[entity], typ == "point" || typ == "polygon"];
        
    // add specified indexes    
    steps += [step(db, mongo(createIndex(db, entity, "{ <intercalate(", ",["\"<attrOrRef>\": 1"| str attrOrRef <- ftrs])>}")), ())
       | <db, indexSpec(str name, entity, list[str] ftrs)> <- s.pragmas];
          
  }
  
  return steps;
 }

list[Step] place2script(p: <neo4j(), str db>, Schema s, Log log = noLog) {
	list[Step] steps = [step(db, neo(executeNeoUpdate(db, 
		neopp(
			nMatchUpdate(
		    	just(
		    		nMatch(
		    			[nPattern(nNodePattern("__n1", [], []), [])],
		    		    [])),
				nDetachDelete([nVariable("__n1")]), 
				[nLit(nBoolean(true))])))), ())];
	return steps;
}
