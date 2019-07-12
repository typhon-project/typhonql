module lang::typhonql::Compiler

import lang::typhonql::TDBC;
import lang::typhonql::Partition;
import lang::typhonql::relational::Compiler;
import lang::typhonql::mongodb::Compiler;

import lang::typhonml::TyphonML;
import lang::typhonml::Util;


lrel[Place, value] compile(Request request, Schema schema) {
  lrel[Place, Request] script = partition(request, schema);
  return [ *compile(p, r) | <Place p, Request r> <- script ];
}

lrel[Place, value] compile(p:<mongodb(), _>, Request r, Schema s) 
  = [ <p, compile2mongo(r, s)> ];


lrel[Place, value] compile(p:<sql(), _>, Request r, Schema s) 
  = [ <p, pp(stat)> | SQLStat stat <- compile2sql(r, s) ];


default lrel[Place, value] compile(Place p, Request _, Schema _) {
  throw "Unsupported DB type <p.db>";
}

