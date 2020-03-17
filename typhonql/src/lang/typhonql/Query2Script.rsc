module lang::typhonql::Query2Script

import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::Script;
import lang::typhonql::Session;
import lang::typhonql::TDBC;
import lang::typhonql::Order;
import lang::typhonql::Normalize;


import lang::typhonql::relational::SQL;
import lang::typhonql::relational::Util;
import lang::typhonql::relational::SQL2Text;
import lang::typhonql::relational::Query2SQL;

import lang::typhonql::mongodb::Query2Mongo;
import lang::typhonql::mongodb::DBCollection;

import IO;
import List;

list[Step] compileQuery(r:(Request)`<Query q>`, p:<sql(), str dbName>, Schema s) {
  //r = expandNavigation(addWhereIfAbsent(r), s);
  println("COMPILING: <r>");
  <sqlStat, params> = compile2sql(r, s, p);
  // hack
  if (sqlStat.exprs == []) {
    return [];
  }
  return [step(dbName, sql(executeQuery(dbName, pp(sqlStat))), params)];
}

list[Step] compileQuery(r:(Request)`<Query q>`, p:<mongodb(), str dbName>, Schema s) {
  <methods, params> = compile2mongo(r, s, p);
  for (str coll <- methods) {
    // TODO: signal if multiple!
    return [step(dbName, mongo(find(dbName, coll, pp(methods[coll].query), pp(methods[coll].projection))), params)];
  }
  return [];
}
