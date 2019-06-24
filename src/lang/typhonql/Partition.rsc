module lang::typhonql::Partition


import lang::typhonml::Util;
import lang::typhonql::Query;
import lang::typhonql::Expr;

import IO;
import Set;

rel[Place place, Query query] select2sql(q:(Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ es>`, Schema s) {
  
  // iterate over all databases/places
    // restrict bindings to entities on the current db
    // kick out results that are not on the current db
    // add entities that are on this db, and are needed for cross where clauses involving this db
    //   and add bindings for them
    // filter where clauses to expressions only local to this db.
  
}



bool isLocalTo(Expr e, DB db, map[str, str] env, Schema s)
  = dbPlaces(e, env, s)<0> == {db};

// an expression is "local to a db" when all entities traversed by its paths are within the same DB 
bool isLocal(Expr e, map[str, str] env, Schema s)
  = size(dbPlaces(e, env, s)) == 1;
  

set[Place] dbPlaces(Expr e, map[str, str] env, Schema s)
  =  { p | DBPath dp <- dbPaths(e, env, s), <Place p, _> <- dp };


set[DBPath] dbPaths(Expr e, map[str, str] env, Schema s) { 
  set[DBPath] paths = {};
  visit (e) {
    case (Expr)`<VId x>.<{Id "."}+ xs>`: 
       paths += {navigate(env["<x>"], [ "<f>" | Id f <- xs ], s)};
    case (Expr)`<VId x>` :
       paths += {navigate(env["<x>"], [], s)};
    case (Expr)`<VId x>.@id` :
       paths += {navigate(env["<x>"], [], s)};
  }
  return paths;
}


DBPath navigate(str entity, list[str] path, Schema s) {

  // for now we abstract from dbname, since it couples directly to entity
  // (IOW: it's not a db abstraction, but a table/collection abstraction)
  // -> this is a problem in TyphonML
  // so we make name always ""

  Place myPlace() = <db, ""> when <DB db, str name, entity> <- s.placement;

  if (path == []) {
    return [<myPlace(), entity>];
  }
  
  str head = path[0];
  if (<entity, _, head, _, _, str to, _> <- s.rels) {
    return [<myPlace(), entity>] + navigate(to, path[1..], s);
  }
  else if (<entity, head, _> <- s.attrs) {
    return [<myPlace(), entity>];
  }
  else { 
    throw "No such field in schema <head>";
  } 
}



alias Place = tuple[DB db, str name];

alias DBPath = lrel[Place place, str entity];




//data Plan
//  = plan(Query combine, rel[Conf, Query] delegates);
//
//alias Dist = rel[Conf conf, str var];
//
//
//Plan queryPlan(Query q, Schema s) = plan(recombine(q, d), partition(q, d))
//  when
//    Dist d := placement(q, s);
//
//
//rel[Conf, Query] partition(Query q, Dist d) = { <c, restrict(q, d[c], d)> | Conf c <- d<conf> };
//  
//
//Dist placement(Query q, Schema s) 
//  = { <c, x> | let(str e, str x) <- q.bindings, Conf c <- s.entities, entity(e, _) := s.entities[c] };
//
//
//bool isLocal(Clause w,  set[str] xs) = !(/attr(str y, _) := w && y notin xs);
//
//
//// a clause is cross db, when not all of it's referred attrs are on a single conf
//bool isCross(Clause w, Dist d) = !(Conf c <- d<conf> && xs <= d[c])
//  when
//    set[str] xs := { x | /attr(str x, _) := w };
//
//Query recombine(Query q, Dist d) = q[where = [ w | Clause w <- q.where, isCross(w, d) ] ];
//
//Query restrict(Query q, set[str] xs, Dist d) 
//  = from([ b | Binding b <- q.bindings, b.name in xs ],  // keep only bindings for xs
//  
//       // add to select if not already there
//       // NB: only add x out of xs to result set when x *also* participates in a
//       // cross clause. Otherwise there's no need to return it.
//       select = dup([ a | Clause w <- q.where, isCross(w, d), /a:attr(str x, _) := w, x in xs ]
//           + [ a | a:attr(str x, _) <- q.select, x in xs ]),  
//       
//       // keep only clauses that only are on xs in some way
//       where = [ w | Clause w <- q.where, isLocal(w, xs) ]
//    );
//
//str pp(plan(Query q0, rel[Conf, Query] ds)) 
//  = "<pp(q0)>
//    '
//    '<for (<Conf c, Query q> <- ds) {>
//    '<pp(c)>
//    '<pp(q)>
//    '<}>"; 
