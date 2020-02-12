module lang::typhonql::Request2Script


import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::Script;
import lang::typhonql::relational::Query2SQL;
import lang::typhonql::TDBC;
import lang::typhonql::Order;
import lang::typhonql::Normalize;
import lang::typhonql::relational::SQL;
import lang::typhonql::relational::SQL2Text;

import IO;

Script request2script(r:(Request)`<Query q>`, Schema s) {
  r = expandNavigation(addWhereIfAbsent(r), s);
  list[Place] order = orderPlaces(r, s);
  
  Script scr = script([]); 
  
  // TODO change
  for (Place p <- order, p.db is sql) {
    Request r = restrict(r, p, order, s);
    scr.steps += compile(r, p, s);
  }
  return scr;
}

list[Step] compile(r:(Request)`<Query q>`, p:<sql(), str dbName>, Schema s) {
  <sqlStat, params> = compile2sql(r, s, p);
  return [step(dbName, sql(executeQuery(dbName, pp(sqlStat))), params)];
}

void smokeScript() {
  s = schema({
    <"Person", zero_many(), "reviews", "user", \one(), "Review", true>,
    <"Review", \one(), "user", "reviews", \zero_many(), "Person", false>,
    <"Review", \one(), "comment", "owner", \zero_many(), "Comment", true>,
    <"Comment", zero_many(), "replies", "owner", \zero_many(), "Comment", true>
  }, {
    <"Person", "name", "String">,
    <"Person", "age", "int">,
    <"Review", "text", "String">,
    <"Comment", "contents", "String">,
    <"Reply", "reply", "String">
  },
  placement = {
    <<sql(), "Inventory">, "Person">,
    <<sql(), "Reviews">, "Review">,
    <<sql(), "Reviews">, "Comment">
  } 
  );
  
  Request q = (Request)`from Person p, Review r select r.text, p.name where p.name == "Pablo", p.reviews == r`;  
  iprintln(request2script(q, s));
}  
