module lang::typhonql::Schema2Script

import IO;
import ValueIO;
import List;
import String;

import lang::typhonml::Util;
import lang::typhonql::Script;
import lang::typhonql::Session;
import lang::typhonql::relational::SchemaToSQL;
import lang::typhonql::cassandra::Schema2CQL;
import lang::typhonql::cassandra::CQL;
import lang::typhonql::cassandra::CQL2Text;

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
  return [ step(db, cassandra(execute(pp(stmt))), ()) 
     | CQLStat stmt <-  schema2cql(s, p, s.placement[p]) ];
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


    // add geo indexes
    steps += [step(db, mongo(createIndex(db, entity, attr, "2dsphere")), ()) 
        | <str attr, str typ> <- s.attrs[entity], typ == "point" || typ == "polygon"];
    // TODO: add other kinds of indexes from model
  }
  return steps;
}