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

import lang::typhonql::util::Log;

import IO;
import List;

Env queryEnvAndDyn(Query q) = queryEnvAndDyn(q.bindings);

Env queryEnvAndDyn({Binding ","}+ bs)
 = queryEnv(bs) + ("<x>": "<e>" | (Binding)`#dynamic(<EId e> <VId x>)` <- bs )
  + ("<x>": "<e>" | (Binding)`#ignored(<EId e> <VId x>)` <- bs );

list[Path] results2paths({Result ","}+ rs, Env env, Schema s)
  = [ *exp2path(e, env, s) | (Result)`<Expr e>` <- rs ];

list[Path] where2paths((Where)`where <{Expr ","}+ ws>`, Env env, Schema s) 
  = [  *exp2path(w, env, s) | Expr w <- ws ];

list[Path] exp2path((Expr)`<VId x>`, Env env, Schema s)
  = exp2path((Expr)`<VId x>.@id`, env, s);


list[Path] exp2path((Expr)`<VId x>.@id`, Env env, Schema s)
  = [<p.name, "<x>", ent, ["@id"]>]
  when
    str ent := env["<x>"],
    <Place p, ent> <- s.placement;

// this mimicks addProjections in toMongo (or at least tries to)
list[Path] exp2path((Expr)`#needed(<Expr e>)`, Env env, Schema s)
  = [*exp2path(e2, env, s) | /Expr e2 := e ];

// assumes expand navigation normalization
list[Path] exp2path((Expr)`<VId x>.<Id f>`, Env env, Schema s)
  = [<p.name, "<x>", ent, ["<f>"]>]
  when
    str ent := env["<x>"],
    <Place p, ent> <- s.placement;

default list[Path] exp2path(Expr _, Env _, Schema _) = [];

list[Path] filterForBackend(list[Path] paths, Place p)
  = [ path | Path path <- paths, path.dbName == p.name ];


Where getWhere((Query)`from <{Binding ","}+ _> select <{Result ","}+ _> <Where w>`)
  = w;

list[Step] compileQuery(r:(Request)`<Query q>`, p:<sql(), str dbName>, Schema s, Log log = noLog) {
  //r = expandNavigation(addWhereIfAbsent(r), s);
  log("COMPILING: <r>");
  <sqlStat, params> = compile2sql(r, s, p);
  // hack

  if (sqlStat.exprs == []) {
    return [];
  }
  return [step(dbName, sql(executeQuery(dbName, pp(sqlStat))), params
     , signature=
         filterForBackend(results2paths(q.selected, queryEnvAndDyn(q), s)
           +  where2paths(getWhere(q), queryEnvAndDyn(q), s), p))];
}

list[Step] compileQuery(r:(Request)`<Query q>`, p:<mongodb(), str dbName>, Schema s, Log log = noLog) {
  log("COMPILING2Mongo: <r>");
  <methods, params> = compile2mongo(r, s, p);
  for (str coll <- methods) {
    // TODO: signal if multiple!
    return [step(dbName, mongo(find(dbName, coll, pp(methods[coll].query), pp(methods[coll].projection)))
      , params, signature=
         filterForBackend(results2paths(q.selected, queryEnvAndDyn(q), s) + where2paths(getWhere(q), queryEnvAndDyn(q), s), p)
         )];
  }
  return [];
}
