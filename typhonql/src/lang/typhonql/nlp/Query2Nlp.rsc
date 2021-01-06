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

module lang::typhonql::nlp::Query2Nlp

import lang::typhonql::TDBC;
import lang::typhonql::Normalize;
import lang::typhonql::Order;
import lang::typhonql::Script;
import lang::typhonql::Session;

import lang::typhonml::Util;

import lang::typhonql::util::Log;
import lang::typhonql::util::Strings;
import lang::typhonql::util::Dates;

import lang::typhonql::nlp::Nlp;

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

tuple[NStat, Bindings] compile2nlp((Request)`<Query q>`, Schema s, Place p, Log log = noLog)
  = select2nlp(q, s, p, log = log);

tuple[NStat, Bindings] select2nlp((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs>`, Schema s, Place p, Log log = noLog) 
  = select2nlp((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where true`, s, p, log = log);


tuple[NStat, Bindings] select2nlp((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ ws>`
  , Schema s, Place p, Log log = noLog) {
  
  NExpr expr2nlp((Expr)`<VId x>`) = expr2nlp((Expr)`<VId x>.@id`);

	// NB: hardcoding @id here, because no env abvailabe....
	NExpr expr2nlp((Expr)`<VId x>.@id`) = nAttr("<x>", [ "@id" ]);
	
	NExpr expr2nlp((Expr)`<VId x>.<Id f>`) {
		addWith("<x>", env["<x>"], "<f>", s);
		return nAttr("<x>", split("$", "<f>"));
	}
	
	NExpr expr2nlp((Expr)`??<Id x>`) = nPlaceholder("<x>");
	
	NExpr expr2nlp((Expr)`<Int i>`) = nLiteral("<i>", "int");
	
	NExpr expr2nlp((Expr)`<Real r>`) = nLiteral("<i>", "float");
	
	NExpr expr2nlp((Expr)`<Str s>`) = nLiteral(unescapeQLString(s), "string");
	
	// a la cql timestamp
	NExpr expr2nlp((Expr)`<DateAndTime d>`) 
	  = nLiteral(printUTCDate(convert(d), "yyyy-MM-dd\'T\'HH:mm:ss.SSSXX"), "datetime");
	
	NExpr expr2nlp((Expr)`<JustDate d>`)  
	  = nLiteral(printDate(convert(d), "yyyy-MM-dd"), "date");
	
	NExpr expr2nlp((Expr)`<UUID u>`) = nLiteral("<u>"[1..], "uuid");
	
	NExpr expr2nlp((Expr)`<PlaceHolder ph>`) =  nPlaceholder("<ph.name>");
	
	NExpr expr2nlp((Expr)`true`) = nLiteral("true", "boolean");
	
	NExpr expr2nlp((Expr)`false`) = nLiteral("false", "boolean");
	
	NExpr expr2nlp((Expr)`(<Expr e>)`) = expr2nlp(e);
	
	NExpr expr2nlp((Expr)`null`) = cTerm(cNull());
	
	NExpr expr2nlp((Expr)`+<Expr e>`) = expr2nlp(e);
	
	NExpr expr2nlp((Expr)`-<Expr e>`) = nUnaryOp("-", expr2nlp(e));
	
	NExpr expr2nlp((Expr)`!<Expr e>`) = nUnaryOp("!", expr2nlp(e));
	
	NExpr expr2nlp((Expr)`<Expr lhs> && <Expr rhs>`) 
	  = nBinaryOp("&&", expr2nlp(lhs), expr2nlp(rhs));
	
	NExpr expr2nlp((Expr)`<Expr lhs> || <Expr rhs>`) 
	  = nBinaryOp("||", expr2nlp(lhs), expr2nlp(rhs));
	
	NExpr expr2nlp((Expr)`<Expr lhs> * <Expr rhs>`) 
	  = nBinaryOp("*", expr2nlp(lhs), expr2nlp(rhs));
	
	NExpr expr2nlp((Expr)`<Expr lhs> / <Expr rhs>`) 
	  = nBinaryOp("/", expr2nlp(lhs), expr2nlp(rhs));
	
	NExpr expr2nlp((Expr)`<Expr lhs> + <Expr rhs>`) 
	  = nBinaryOp("+", expr2nlp(lhs), expr2nlp(rhs));
	
	NExpr expr2nlp((Expr)`<Expr lhs> - <Expr rhs>`) 
	  = nBinaryOp("-", expr2nlp(lhs), expr2nlp(rhs));
	
	NExpr expr2nlp((Expr)`<Expr lhs> == <Expr rhs>`) 
	  = nBinaryOp("==", expr2nlp(lhs), expr2nlp(rhs));
	  
	NExpr expr2nlp(e:(Expr)`<Expr lhs> #join <Expr rhs>`) { throw "Unsupported expression in NLP: <e>"; }
	
	NExpr expr2nlp((Expr)`<Expr lhs> != <Expr rhs>`) 
	  = nBinaryOp("!=", expr2nlp(lhs), expr2nlp(rhs));
	
	NExpr expr2nlp((Expr)`<Expr lhs> \>= <Expr rhs>`) 
	  = nBinaryOp("\>=", expr2nlp(lhs), expr2nlp(rhs));
	
	NExpr expr2nlp((Expr)`<Expr lhs> \<= <Expr rhs>`) 
	  = nBinaryOp("\<=", expr2nlp(lhs), expr2nlp(rhs));
	
	NExpr expr2nlp((Expr)`<Expr lhs> \> <Expr rhs>`) 
	  = nBinaryOp("\>", expr2nlp(lhs), expr2nlp(rhs));
	
	NExpr expr2nlp((Expr)`<Expr lhs> \< <Expr rhs>`) 
	  = nBinaryOp("\<", expr2nlp(lhs), expr2nlp(rhs));
	
	NExpr expr2nlp((Expr)`<Expr lhs> in <Expr rhs>`)
	  = nBinaryOp("in", expr2nlp(lhs), expr2nlp(rhs));


	default NExpr expr2nlp(Expr e) { throw "Unsupported expression in NLP: <e>"; }
  
  

  NStat q = nSelect(nFrom("", ""), [], [], nLiteral("true", "bool"));
  
  void addWhere(NExpr e) {
     //println("ADDING where clause: <pp(e)>");
    if (nLiteral("true", "bool") := q.where) {
    	q.where = e;
    } else {
    	q.where = nBinaryOp("&&", e, q.where);
    }
  }
  
  void addResult(NPath selector) {
    q.selectors += [selector];
  }
  
  void addWith(str entityVar, str entity, str field, Schema s) {
    db = split("__", entity)[0];
    fragments = split("$", field);
    attribute = fragments[0];
    analysis = fragments[1];
  	if (<db, nlpSpec(workflows)> <- s.pragmas, <entity, attribute, analysis, w> <- workflows) {
  		with = nWith(nPath(entityVar, [attribute, *split("$", analysis)]), w);
  		if (with notin q.withs)
  			q.withs += [with];
  	}
  }
  
  //addResult(cSelector(expr2nlp(cTyphonId(), as="<y>.<ent>.@id"
  
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
           addResult(nPath("<y>", ["@id"]));
           for (<ent, str a, str _> <- s.attrs) {
             Id f = [Id]a;
             addResult(nPath("<y>", split("$", "<f>")));
           }
         }
       }
      case x:(Expr)`<VId y>.@id`: {
         log("##### record results: var <y>.@id");
    
         if (str ent := env["<y>"], <p, ent> <- s.placement) {
           addResult(nPath("<y>", ["@id"]));
         }
      }
      case x:(Expr)`<VId y>.<Id f>`: {
         log("##### record results: <y>.<f>");
         
         if (str ent := env["<y>"], <p, ent> <- s.placement) {
           addWith("<y>", env["<y>"], "<f>", s);
           addResult(nPath("<y>", split("$", "<f>")));
         }
         
          // always add the @id
          //if (str ent := env["<y>"], <p, ent> <- s.placement) {
          //   addResult(nPath("<y>", ["@id"]));
          //}
      }
      
      // TODO missing case for path longer than 1
    }
  }

  // NB: if, not for, there can only be a single "from"
  myBindings = [ b | b:(Binding)`<EId e> <VId x>` <- bs ];
  /*if (size(myBindings) > 1) {
    throw "Currently subsets of entity attribute can only mapped to NLP once per entity";
  }*/
  
  q.from = nFrom("<myBindings[0].entity>", "<myBindings[0].var>");
  
 
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
        addWhere(expr2nlp(e));
    }
  }
  
  return <q, params>;
}
 

