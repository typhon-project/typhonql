module lang::typhonql::Partition


import lang::typhonml::Util;
import lang::typhonql::TDBC;


import IO;
import Set;
import String;
import List;


@doc{
The partitioning is a map from place to request
Places include 
- named database back-ends sql() mongodb()
- anonymous recombination queries (in case of select-query partitioning)
- the original request with db type "typhon()"

TODO: integrate name into the DB type instead of tupling
}
alias Partitioning = map[Place place, Request request];


void partitionSmokeTest() {
  q = (Request)`from Product p select p.review where p.name != "", p.review.id != ""`;
  s = myDbSchema();
  println(partition2text(partition(q, s)));
}

/*

for object graphs: first flatten, then distribute, then for mongo unflatten to get containment back.

*/

str partition2text(Partitioning pr) {
  str s = "ORIGINAL:\n  <pr[<typhon(), "">]>\n";
  s += "PARTITIONING:\n";
  for (Place p <- pr, p.db != typhon(), p.db != recombine()) {
    s += "  <p>: <pr[p]>\n";
  }
  s += "RECOMBINE:\n  <pr[<recombine(), "">]>";
  return s;
}


Partitioning partition((Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs>`, Schema s) 
  = partition((Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where true`, s);


Partitioning partition(q:(Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ es>`, Schema s) {
  map[str, str] env = ( "<x>": "<e>"  | (Binding)`<EId e> <VId x>` <- bs );
   
   
  int varId = 0;
  str newVar(str base) {
    str x = "<uncapitalize(base)>_<varId>";
    varId += 1;
    return x;
  }
  
  map[Place, Request] result = (<typhon(), "">: q);
   
   // An end-result of this phase, is that we have a (unique?) variable for every entity...
   // Another invariant: in the combined result set  of the back-end queries
   // we have all entities available that are in the original binding set.
    
    
  for (Place p <- s.placement<0>) {
   
    // restrict bindings to bindings on the current place
    newBindings = [ b | Binding b <- bs, str e := "<b.entity>", <p, e> <- s.placement ];
    
    // kick out results that are not on the current db
    newResults = [ r | r:(Result)`<Expr re>` <- rs, isLocalTo(re, p, env, s) ];
    
    // need to add results for bindings that are local, but not in the result
    newResults += [ (Result)`<VId x>` | (Binding)`<EId e> <VId x>` <- bs, isLocalTo((Expr)`<VId x>`, p, env, s) ]; 
    
    set[str] addedEntities = { e | Expr w <- es, <p, str e> <- dbPlacements(w, env, s) }
      + { e | (Result)`<Expr r>` <- rs, <p, str e> <- dbPlacements(r, env, s) };
      
    //println("Added entities: <addedEntities>");  
      
    rel[EId, VId] addedBindings = { <eid, x> | str e <- addedEntities,
      EId eid := [EId]e, !((Binding)`<EId eid> <VId _>` <- newBindings), VId x := [VId]newVar(e) };
    
    //for (<eid, vid> <- addedBindings) {
    //  println("Adding binding: <eid> <vid>");
    //}
    
    // Add bindings for required cross-clause evaluation 
    newBindings += [ (Binding)`<EId eid> <VId x>` | <EId eid, VId x> <- addedBindings ]; 
    newResults += [ (Result)`<VId x>` | VId x <- addedBindings<1> ];

    // filter where clauses to expressions only local to this db.
    newWheres = [ e | Expr e <- es, isLocalTo(e, p, env, s) ];
    
    // project where expressions to the entities that are local to p
    // p.review.id != "" will become (newVar for entity Review).id != "")
    // for every a.b.c replace the path to the entity that's added with its var.
    // --> future work; currently these things would be evaluated at recombining stage
    
    
    
     
    Query newQ = buildQuery(newBindings, newResults, newWheres);
    
    result[p] = (Request)`<Query newQ>`;
  }
  
  // Recombination query
  
  newWheres = [ e | Expr e <- es, !isLocal(e, env, s) ];
  
  Query recomb = buildQuery([ b | Binding b <- bs ], [ r | Result r <- rs ], newWheres); 
  result[<recombine(), "">] =  (Request)`<Query recomb>`;

  return result;
}

Query buildQuery(list[Binding] bs, list[Result] rs, list[Expr] ws) {
  Binding b0 = bs[0];
  Result r0 = rs[0];
  Query q = (Query)`from <Binding b0> select <Result r0> where true`;
  wherePos = 0;
  if (size(ws) > 0) {
    Expr w = ws[0];
    q = (Query)`from <Binding b0> select <Result r0> where <Expr w>`;
    wherePos = 1;
  }
  
  for (Binding b <- bs[1..]) {
    if ((Query)`from <{Binding ","}+ theBs> select <{Result ","}+ theRs> where <{Expr ","}+ theWs>` := q) {
      q = (Query)`from <{Binding ","}+ theBs>, <Binding b> select <{Result ","}+ theRs> where <{Expr ","}+ theWs>`;
    }
  }
  for (Result r <- rs[1..]) {
    if ((Query)`from <{Binding ","}+ theBs> select <{Result ","}+ theRs> where <{Expr ","}+ theWs>` := q) {
      q = (Query)`from <{Binding ","}+ theBs> select <{Result ","}+ theRs>, <Result r> where <{Expr ","}+ theWs>`;
    }
  }
  for (Expr w <- ws[wherePos..]) {
    if ((Query)`from <{Binding ","}+ theBs> select <{Result ","}+ theRs> where <{Expr ","}+ theWs>` := q) {
      q = (Query)`from <{Binding ","}+ theBs> select <{Result ","}+ theRs> where <{Expr ","}+ theWs>, <Expr w>`;
    }
  }
  return q;
}


alias DBPath = lrel[Place place, str entity];

bool goesThrough(Expr e, Place p, map[str, str] env, Schema s) 
  = p in dbPlaces(e, env, s);

bool isLocalTo(Expr e, Place p, map[str, str] env, Schema s)
  = dbPlaces(e, env, s) == {p};

// an expression is "local to a db" when all entities traversed by its paths are within the same DB 
bool isLocal(Expr e, map[str, str] env, Schema s)
  = size(dbPlaces(e, env, s)) == 1;
  

rel[Place, str] dbPlacements(Expr e, map[str, str] env, Schema s)
  =  { <p, e> | DBPath dp <- dbPaths(e, env, s), <Place p, str e> <- dp };

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
  if (<Place myPlace, entity> <- s.placement) {
    if (path == []) {
      return [<myPlace, entity>];
    }
  
    str head = path[0];
    if (<entity, _, head, _, _, str to, _> <- s.rels) {
      return [<myPlace, entity>] + navigate(to, path[1..], s);
    }
    else if (<entity, head, _> <- s.attrs) {
      return [<myPlace, entity>];
    }
    else { 
      throw "No such field in schema <head>";
    }
  }
  else {
    throw "No placement for entity <entity>";
  } 
}




