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

module lang::typhonql::cassandra::Query2CQL

import lang::typhonql::TDBC;
import lang::typhonql::Normalize;
import lang::typhonql::Order;
import lang::typhonql::Script;
import lang::typhonql::Session;

import lang::typhonml::Util;

import lang::typhonql::cassandra::CQL;
import lang::typhonql::cassandra::CQL2Text;
import lang::typhonql::cassandra::Schema2CQL;


import lang::typhonql::util::Log;
import lang::typhonql::util::Strings;
import lang::typhonql::util::Dates;

import String;
import ValueIO;
import DateTime;
import List;
import IO;


/*
 * Queries partitioned to cassandra
 * are simpler than ordinary queries
 * because there are no relations
 * in keyValue "entities".
 */

tuple[CQLStat, Bindings] compile2cql((Request)`<Query q>`, Schema s, Place p, Log log = noLog)
  = select2cql(q, s, p, log = log);

tuple[CQLStat, Bindings] select2csql((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs>`, Schema s, Place p, Log log = noLog) 
  = select2cql((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where true`, s, p, log = log);


tuple[CQLStat, Bindings] select2cql((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ ws>`
  , Schema s, Place p, Log log = noLog) {

  CQLStat q = cSelect([], "", [], allowFiltering=true);
  
  void addWhere(CQLExpr e) {
     //println("ADDING where clause: <pp(e)>");
    q.wheres += [e];
  }
  
  void addResult(CQLSelectClause e) {
    q.selectClauses += [e];
  }
  
  //addResult(cSelector(expr2cql(cTyphonId(), as="<y>.<ent>.@id"
  
  int _vars = -1;
  int vars() {
    return _vars += 1;
  }

  Bindings params = ();
  void addParam(str x, Param field) {
    params[x] = field;
  }
  
  map[Param, str] placeholders = ();
  str getParam(str prefix, Param field) {
    if (field notin placeholders) {
      str name = "<prefix>_<vars()>";
      placeholders[field] = name;
      addParam(name, field);
    } 
    return placeholders[field];
  }

  Env env = (); 
  set[str] dyns = {};
  for (Binding b <- bs) {
    switch (b) {
      case (Binding)`<EId e> <VId x>`:
        env["<x>"] = "<e>";
      case (Binding)`#dynamic(<EId e> <VId x>)`: {
        env["<x>"] = "<e>";
        dyns += {"<x>"};
      }
      case (Binding)`#ignored(<EId e> <VId x>)`:
        env["<x>"] = "<e>";
    }
  }
  
  void recordResults(Expr e) {
    log("##### record results");
    visit (e) {
      case x:(Expr)`<VId y>`: {
         // this is probably dead because of lone var elimination
         log("##### record results: var <y>");
    
         if (str ent := env["<y>"], <p, ent> <- s.placement) {
           addResult(cSelector(expr2cql(x), as="<y>.<ent>.@id"));
           for (<ent, str a, str _> <- s.attrs) {
             Id f = [Id]a;
             addResult(cSelector(expr2cql((Expr)`<VId y>.<Id f>`), as="<y>.<ent>.<f>"));
           }
         }
       }
      case x:(Expr)`<VId y>.@id`: {
         log("##### record results: var <y>.@id");
    
         if (str ent := env["<y>"], <p, ent> <- s.placement) {
           addResult(cSelector(expr2cql(x), as="<y>.<ent>.@id"));
         }
      }
      case x:(Expr)`<VId y>.<Id f>`: {
         log("##### record results: <y>.<f>");
    
         if (str ent := env["<y>"], <p, ent> <- s.placement) {
           addResult(cSelector(expr2cql(x), as="<y>.<ent>.<f>"));
         }
         
         // always add the @id
         if (str ent := env["<y>"], <p, ent> <- s.placement) {
           addResult(cSelector(expr2cql((Expr)`<VId y>.@id`), as="<y>.<ent>.@id"));
         }
      }
    }
  }

  // NB: if, not for, there can only be a single "from"
  myBindings = [ b | b:(Binding)`<EId e> <VId x>` <- bs ];
  if (size(myBindings) > 1) {
    throw "Currently subsets of entity attribute can only mapped to key-stores once per entity";
  }
  
  q.tableName = cTableName("<myBindings[0].entity>");

  for ((Result)`<Expr e>` <- rs) {
    switch (e) {
      case (Expr)`#done(<Expr x>)`: ;
      case (Expr)`#delayed(<Expr x>)`: ;
      case (Expr)`#needed(<Expr x>)`: 
        recordResults(x);
      default:
        recordResults(e);
    }
  }

  Expr rewriteDynIfNeeded(e:(Expr)`<VId x>.@id`) {
    if ("<x>" in dyns, str ent := env["<x>"], <Place p, ent> <- s.placement) {
      str token = getParam("<x>", field(p.name, "<x>", env["<x>"], "@id"));
      return [Expr]"??<token>";
    }
    return e;
  }
  
  // todo: refactor this and above.
  Expr rewriteDynIfNeeded(e:(Expr)`<VId x>.<Id f>`) {
    if ("<x>" in dyns, str ent := env["<x>"], <Place p, ent> <- s.placement) {
      str token = getParam("<x>", field(p.name, "<x>", env["<x>"], "@id"));
      return [Expr]"??<token>";
    }
    return e;
  }
  
  ws = visit (ws) {
    case (Expr)`<VId x>` => rewriteDynIfNeeded((Expr)`<VId x>.@id`)
    case e:(Expr)`<VId x>.@id` => rewriteDynIfNeeded(e)
    case e:(Expr)`<VId x>.<Id f>` => rewriteDynIfNeeded(e)
  }
  

  for (Expr e <- ws) {
    switch (e) {
      case (Expr)`#needed(<Expr x>)`:
        recordResults(x);
      case (Expr)`#done(<Expr _>)`: ;
      case (Expr)`#delayed(<Expr _>)`: ;
      default: 
        addWhere(expr2cql(e));
    }
  }
  
  q.wheres = [ e | CQLExpr e <- q.wheres, e != cTerm(cBoolean(true)) ];
  return <q, params>;
}
 

CQLExpr expr2cql((Expr)`<VId x>`) = expr2cql((Expr)`<VId x>.@id`);

// NB: hardcoding @id here, because no env abvailabe....
CQLExpr expr2cql((Expr)`<VId x>.@id`) = CQLExpr::cColumn("@id");

CQLExpr expr2cql((Expr)`<VId x>.<Id f>`) = CQLExpr::cColumn("<f>");

CQLExpr expr2cql((Expr)`?`) = cBindMarker();

CQLExpr expr2cql((Expr)`??<Id x>`) = cBindMarker(name="<x>");

CQLExpr expr2cql((Expr)`<Int i>`) = cTerm(cInteger(toInt("<i>")));
//CQLExpr expr2cql((Expr)`-<Int i>`) = cTerm(cInteger(toInt("-<i>")));

CQLExpr expr2cql((Expr)`<Real r>`) = cTerm(cFloat(toReal("<r>")));
//CQLExpr expr2cql((Expr)`-<Real r>`) = cTerm(cFloat(toReal("-<r>")));

CQLExpr expr2cql((Expr)`<Str s>`) = cTerm(cString(unescapeQLString(s)));

// a la cql timestamp
CQLExpr expr2cql((Expr)`<DateAndTime d>`) 
  = cTerm(cString(printUTCDate(convert(d), "yyyy-MM-dd\'T\'HH:mm:ss.SSSXX")));

CQLExpr expr2cql((Expr)`<JustDate d>`)  
  = cTerm(cString(printDate(convert(d), "yyyy-MM-dd")));

CQLExpr expr2cql((Expr)`<UUID u>`) = cTerm(cUUID("<u>"[1..]));

CQLExpr expr2cql((Expr)`<PlaceHolder ph>`) = cBindMarker(name = "<ph.name>");

CQLExpr expr2cql((Expr)`true`) = cTerm(cBoolean(true));

CQLExpr expr2cql((Expr)`false`) = cTerm(cBoolean(false));

CQLExpr expr2cql((Expr)`(<Expr e>)`) = expr2cql(e);

CQLExpr expr2cql((Expr)`null`) = cTerm(cNull());

CQLExpr expr2cql((Expr)`+<Expr e>`) = expr2cql(e);

CQLExpr expr2cql((Expr)`-<Expr e>`) = cUMinus(expr2cql(e));

//CQLExpr expr2cql((Expr)`!<Expr e>`) = not(expr2cql(e));

CQLExpr expr2cql((Expr)`<Expr lhs> * <Expr rhs>`) 
  = cTimes(expr2cql(lhs), expr2cql(rhs));

CQLExpr expr2cql((Expr)`<Expr lhs> / <Expr rhs>`) 
  = cDiv(expr2cql(lhs), expr2cql(rhs));

CQLExpr expr2cql((Expr)`<Expr lhs> + <Expr rhs>`) 
  = cPlus(expr2cql(lhs), expr2cql(rhs));

CQLExpr expr2cql((Expr)`<Expr lhs> - <Expr rhs>`) 
  = cMinus(expr2cql(lhs), expr2cql(rhs));

CQLExpr expr2cql((Expr)`<Expr lhs> == <Expr rhs>`) 
  = cEq(expr2cql(lhs), expr2cql(rhs));
  
CQLExpr expr2cql((Expr)`<Expr lhs> #join <Expr rhs>`)
  = cEq(expr2cql(lhs), expr2cql(rhs));
  

CQLExpr expr2cql((Expr)`<Expr lhs> != <Expr rhs>`) 
  = cNeq(expr2cql(lhs), expr2cql(rhs));

CQLExpr expr2cql((Expr)`<Expr lhs> \>= <Expr rhs>`) 
  = cGeq(expr2cql(lhs), expr2cql(rhs));

CQLExpr expr2cql((Expr)`<Expr lhs> \<= <Expr rhs>`) 
  = cLeq(expr2cql(lhs), expr2cql(rhs));

CQLExpr expr2cql((Expr)`<Expr lhs> \> <Expr rhs>`) 
  = cGt(expr2cql(lhs), expr2cql(rhs));

CQLExpr expr2cql((Expr)`<Expr lhs> \< <Expr rhs>`) 
  = cLt(expr2cql(lhs), expr2cql(rhs));

CQLExpr expr2cql((Expr)`<Expr lhs> in <Expr rhs>`)
  = cIn(expr2cql(lhs), expr2cql(rhs));


default CQLExpr expr2cql(Expr e) { throw "Unsupported expression: <e>"; }
