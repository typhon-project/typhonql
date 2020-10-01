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

module lang::typhonql::Aggregation


import lang::typhonql::TDBC;
import lang::typhonql::Normalize;

import util::Maybe;
import IO;

/*


assumptions:
  - expansion of sole vars has happened
  - all aggregate functions are aliased with as

from E1 e1, ..., En en
select xj.fj, ..., fi(...) as xi
where ... (only xj stuff)
group xm.fm, ...
having ... (includes xi's from fi(...)...)


split into:

from E1 e1, ..., En en
select xj.fj, ... + whatever is arg to fi aliased to xi
where ... (only xj stuff)


and

from E1 e1, ..., En en
select xj.fj, ..., fi(...) as xi
where true
group xm.fm, ...
having ... (includes xi's from fi(...)...)


*/


list[Expr] whereExprs((Query)`from <{Binding ","}+ _> select <{Result ","}+ _> where <{Expr ","}+ conds>`)
  = [ c | Expr c <- conds ];
  
list[Expr] whereExprs((Query)`from <{Binding ","}+ _> select <{Result ","}+ _> where <{Expr ","}+ conds> <GroupBy gb>`)
  = [ c | Expr c <- conds ];
  
default list[Expr] whereExprs(Query _) = [];


Maybe[GroupBy] getGroupBy((Query)`from <{Binding ","}+ _> select <{Result ","}+ _> <GroupBy gb>`)
  = just(gb);
  
Maybe[GroupBy] getGroupBy((Query)`from <{Binding ","}+ _> select <{Result ","}+ _> <Where _> <GroupBy gb>`)
  = just(gb);

default Maybe[GroupBy] getGroupBy(Query _)
  = nothing();
   

bool hasAggregation(Query q) = true
  when
    Result r <- q.selected,
    (Result)`<VId agg>(<Expr e>) as <Id x>` := r;
  
  
default bool hasAggregation(Query _) = false;

// we assume agg can be count, max, min, sum, avg
Result liftAgg((Result)`<VId agg>(<Expr e>) as <Id x>`) 
  = (Result)`<Expr e>`;


default Result liftAgg(Result r) = r;



// buildQuery(list[Binding] bs, list[Result] rs, list[Expr] ws) {

tuple[Request, Maybe[Request]] extractAggregation(r:(Request)`<Query q>`) {
  
  if (hasAggregation(q)) {
    // deal with it
    
    list[Result] lifted = [ liftAgg(r) | Result r <- q.selected ];
  
     
    Query newQ = buildQuery([ b | Binding b <- q.bindings ]
      , lifted, whereExprs(q)); // NB: this is without group-by if any
       
    Query aggQ = buildQuery([ b | Binding b <- q.bindings ] 
      , [ r | Result r <- q.selected ] // the originals
      ,  []);
      
    if (just(GroupBy gb) := getGroupBy(q)) {
      if ((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ conds>` := aggQ) {
        aggQ = (Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ conds> <GroupBy gb>`;
      }
      else {
       throw "BUG: buildQuery returns Query that\'s not well-formed: <aggQ>";
      }
    } 
   
    return <(Request)`<Query newQ>`, just((Request)`<Query aggQ>`)>;
  }
  
  // no aggregation present
  return <r, nothing()>;
}

void testAggregationExtraction() {
  void printResult(tuple[Request, Maybe[Request]] result) {
    println("NORMAL: <result[0]>");
    println("AGGREG: <result[1] is just ? result[1].val : "nothing">");
  }

  Request req = (Request)`from User u, Review r
                         'select u.name, count(r.@id) as rc
                         'where u.reviews == r.@id
                         'group u.name having rc \> 2`;
                         
                         
  printResult(extractAggregation(req));
  
  req = (Request)`from User u, Review r
                 'select u.name, r.@id
                 'where u.reviews == r.@id`;

  printResult(extractAggregation(req));
  
}

