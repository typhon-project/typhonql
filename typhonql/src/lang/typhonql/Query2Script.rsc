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

module lang::typhonql::Query2Script

import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::Script;
import lang::typhonql::Session;
import lang::typhonql::TDBC;
import lang::typhonql::Order;
import lang::typhonql::Normalize;


import lang::typhonql::cassandra::Query2CQL;
import lang::typhonql::cassandra::CQL;
import lang::typhonql::cassandra::CQL2Text;


import lang::typhonql::relational::SQL;
import lang::typhonql::relational::Util;
import lang::typhonql::relational::SQL2Text;
import lang::typhonql::relational::Query2SQL;

import lang::typhonql::mongodb::Query2Mongo;
import lang::typhonql::mongodb::DBCollection;

import lang::typhonql::neo4j::Query2Neo;
import lang::typhonql::neo4j::Neo;
import lang::typhonql::neo4j::Neo2Text;

import lang::typhonql::nlp::Query2Nlp;
import lang::typhonql::nlp::Nlp;

import lang::typhonql::util::Log;

import util::Maybe;
import IO;
import List;
import String;

Env queryEnvAndDyn(Query q) = queryEnvAndDyn(q.bindings);

Env queryEnvAndDyn({Binding ","}+ bs)
 = queryEnv(bs) + ("<x>": "<e>" | (Binding)`#dynamic(<EId e> <VId x>)` <- bs )
  + ("<x>": "<e>" | (Binding)`#ignored(<EId e> <VId x>)` <- bs );

list[str] results2colNames({Result ","}+ rs, Env env, Schema s)
  = [ result2colName(r) | Result r <- rs ];

str result2colName((Result)`<Expr e>`) = expr2colName(e);

str result2colName((Result)`<Expr e> as <VId x>`) = "<x>";

str expr2colName((Expr)`<VId x>.@id`) = "<x>.@id";

str expr2colName((Expr)`<VId x>.<Id f>`) = "<x>.<f>";

list[Path] results2pathsWithAggregation({Result ","}+ rs, Env env, Schema s)
  = [ *result2pathWithAggregation(r, env, s) | Result r <- rs ];

list[Path] result2pathWithAggregation((Result)`<Expr e>`, Env env, Schema s)
  = exp2path(e, env, s);

list[Path] result2pathWithAggregation((Result)`<VId agg>(<Expr e>) as <VId x>`, Env env, Schema s)
  = [<dbName, var, ent, ["<x>"]>]
  when
    [<str dbName, str var, str ent, list[str] _>] := exp2path(e, env, s);
    

list[Path] results2paths({Result ","}+ rs, Env env, Schema s)
  = [ *result2path(r, env, s) | Result r <- rs ];

list[Path] result2path((Result)`<Expr e>`, Env env, Schema s)
  = exp2path(e, env, s);

// NB: for the aggregation iteration this should be the aliased variables
// (see expr2colname above)
list[Path] result2path((Result)`<VId agg>(<Expr e>) as <VId _>`, Env env, Schema s)
  = exp2path(e, env, s);


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


Where getWhere((Query)`from <{Binding ","}+ _> select <{Result ","}+ _> <Where w> <Agg* _>`)
  = w;

list[Step] compileQuery(r:(Request)`<Query q>`, p:<sql(), str dbName>, Schema s, 
       Log log = noLog, map[str, Param] initialParams = (), Maybe[Request] agg = Maybe::nothing()) {
  //r = expandNavigation(addWhereIfAbsent(r), s);
  log("COMPILING2SQL: <r>");
  
  SQLStat sqlStat = select([], [], [where([])]);;
  map[str, Param] params = ();
  
  // agg being not nothing implies this is strictly on the current back-end
  if (just(Request aggReq) := agg) {
    <sqlStat, params> = compile2sql(r, s, p, weave = SQLStat(SQLStat stat,  lang::typhonql::relational::Query2SQL::Ctx ctx) {
       return weaveAggregation(aggReq, stat, ctx);
    });
    params += initialParams;
    // hack
    
    return [step(dbName, sql(executeQuery(dbName, pp(sqlStat))), params
      , signature=
          filterForBackend(results2pathsWithAggregation(aggReq.qry.selected, queryEnvAndDyn(aggReq.qry), s)
            +  where2paths(getWhere(aggReq.qry), queryEnvAndDyn(aggReq.qry), s), p))];
  }
  else {
    <sqlStat, params> = compile2sql(r, s, p);
  
    params += initialParams;
    // hack

    if (sqlStat.exprs == []) {
      return [];
    }
    return [step(dbName, sql(executeQuery(dbName, pp(sqlStat))), params
      , signature=
          filterForBackend(results2paths(q.selected, queryEnvAndDyn(q), s)
            +  where2paths(getWhere(q), queryEnvAndDyn(q), s), p))];
  }
  
}

list[Step] compileQuery(r:(Request)`<Query q>`, p:<mongodb(), str dbName>, Schema s, Log log = noLog, map[str, Param] initialParams = (), Maybe[Request] agg = Maybe::nothing()) {
  log("COMPILING2Mongo: <r>");
  <methods, params> = compile2mongo(r, s, p);
  params += initialParams;
  for (str coll <- methods) {
    // TODO: signal if multiple!
    return [step(dbName, mongo(find(dbName, coll, pp(methods[coll].query), pp(methods[coll].projection)))
      , params, signature=
         filterForBackend(results2paths(q.selected, queryEnvAndDyn(q), s) + where2paths(getWhere(q), queryEnvAndDyn(q), s), p)
         )];
  }
  return [];
}

list[Step] compileQuery(r:(Request)`<Query q>`, p:<cassandra(), str dbName>, Schema s, Log log = noLog, map[str, Param] initialParams = (), Maybe[Request] agg = Maybe::nothing()) {
  log("COMPILING2CQL: <r>");
  
  <cqlStat, params> = compile2cql(r, s, p);
  params += initialParams;

  
  if (cqlStat.selectClauses == []) {
    return [];
  }
  return [step(dbName, cassandra(cExecuteQuery(dbName, pp(cqlStat))), params
     , signature=
         filterForBackend(results2paths(q.selected, queryEnvAndDyn(q), s)
           +  where2paths(getWhere(q), queryEnvAndDyn(q), s), p))];
}

list[Step] compileQuery(r:(Request)`<Query q>`, p:<neo4j(), str dbName>, Schema s, Log log = noLog, map[str, Param] initialParams = (), Maybe[Request] agg = Maybe::nothing()) {
  log("COMPILING2neo4j: <r>");
  <neoStat, params> = compile2neo(r, s, p);
  params += initialParams;
  // hack

  if (neoStat.matches[0].patterns == []) {
    return [];
  }
  return [step(dbName, neo(executeNeoQuery(dbName, neopp(neoStat))), params
     , signature=
         filterForBackend(results2paths(q.selected, queryEnvAndDyn(q), s)
           +  where2paths(getWhere(q), queryEnvAndDyn(q), s), p))];
}

list[Step] compileQuery(r:(Request)`<Query q>`, p:<nlp(), str dbName>, Schema s, Log log = noLog, map[str, Param] initialParams = (), Maybe[Request] agg = Maybe::nothing()) {
  log("COMPILING2NLP: <r>");
  
  <nlpStat, params> = compile2nlp(r, s, p);
  params += initialParams;

  
  if (nlpStat.selectors == []) {
    return [];
  }
 
  return [step(dbName, nlp(query(pp(nlpStat))), params
     , signature=
         filterForBackend(results2paths(q.selected, queryEnvAndDyn(q), s)
           +  where2paths(getWhere(q), queryEnvAndDyn(q), s), p))];
}
