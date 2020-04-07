module lang::typhonql::Schema2Script

import IO;
import ValueIO;
import List;
import String;

import lang::typhonml::Util;
import lang::typhonql::Script;
import lang::typhonql::Session;
import lang::typhonql::relational::SchemaToSQL;

import lang::typhonql::util::Log;

import lang::typhonql::relational::SQL;
import lang::typhonql::relational::SQL2Text;

Script schema2script(Schema s, Log log = noLog) {
	list[Step] steps = [];
	for (Place p <- s.placement<0>) {
    	log("[schema2script] generatig script for <p>");
    	steps += place2script(p, s, log = log);
  	}
  	return script(steps);
}

list[Step] place2script(p: <sql(), str db>, Schema s, Log log = noLog) {
  list[Step] steps = [];
  steps += [step(db, sql(executeGlobalStatement(db, "DROP DATABASE IF EXISTS <db>")), ())];
  steps += [step(db, sql(executeGlobalStatement(db, "CREATE DATABASE <db> 
					'   DEFAULT CHARACTER SET utf8mb4 
					'   DEFAULT COLLATE utf8mb4_unicode_ci")), ())];
  list[SQLStat] stats = schema2sql(s, p, s.placement[p], doForeignKeys = false);
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
  }
  return steps;
}