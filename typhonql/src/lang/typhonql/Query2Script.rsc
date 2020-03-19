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

list[Path] results2paths({Result ","}+ rs, Env env, Schema s) 
  = [ *exp2path(e, env, s) | (Result)`<Expr e>` <- rs ];

list[Path] exp2path((Expr)`<VId x>`, Env env, Schema s) 
  = exp2path((Expr)`<VId x>.@id`, env, s);

list[Path] exp2path((Expr)`#needed(<Expr e>)`, Env env, Schema s)
  = [ *exp2path(e2, env, s) | /Expr e2 := e ];

list[Path] exp2path((Expr)`<VId x>.@id`, Env env, Schema s) 
  = [<p.name, "<x>", ent, ["@id"]>]
  when
    str ent := env["<x>"], 
    <Place p, ent> <- s.placement;

list[Path] exp2path((Expr)`<VId x>.<{Id "."}+ fs>`, Env env, Schema s)
  // should this be the final entity, or where the path starts?
  // doing the last option now...
  = [<path[-1].place.name, "<x>", ent, [strFs[-1]]>]
  when
    str ent := env["<x>"], 
    list[str] strFs := [ "<f>" | Id f <- fs ],
    DBPath path := navigate(ent, strFs, s);

default list[Path] exp2path(Expr _, Env _, Schema _) = [];

list[Step] compileQuery(r:(Request)`<Query q>`, p:<sql(), str dbName>, Schema s) {
  r = expandNavigation(addWhereIfAbsent(r), s);
  println("COMPILING: <r>");
  <sqlStat, params> = compile2sql(r, s, p);
  // hack
  
  if (sqlStat.exprs == []) {
    return [];
  }
  return [step(dbName, sql(executeQuery(dbName, pp(sqlStat))), params
     , signature=results2paths(r.qry.selected, queryEnv(q), s))];
}

list[Step] compileQuery(r:(Request)`<Query q>`, p:<mongodb(), str dbName>, Schema s) {
  <methods, params> = compile2mongo(r, s, p);
  for (str coll <- methods) {
    // TODO: signal if multiple!
    return [step(dbName, mongo(find(dbName, coll, pp(methods[coll].query), pp(methods[coll].projection)))
      , params, signature=results2paths(q.selected, queryEnv(q), s))];
  }
  return [];
}
