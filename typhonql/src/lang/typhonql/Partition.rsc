module lang::typhonql::Partition


import lang::typhonml::Util;
import lang::typhonql::TDBC;
import lang::typhonql::util::Objects;


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

}
alias Partitioning = lrel[Place place, Request request];

/*
Alternative: 
alias Partitioning = lrel[Place place, Request request]
the order define order of execution, which is needed for doing recombine
after back-end queries, and (implied) inserts before update,
and (implicit) data flow from implied selects from update/delete

Basically the compiler takes this lrel and then produces/flatMaps it into
lrel[Place place, value] where the value is the back-end specific query
*/


void partitionSmokeTest() {
  s = myDbSchema();
  
  q = (Request)`from Product p select p.review where p.name != "", p.review.id != ""`;
  println("PARTITIONING: <q>");
  println(partition2text(partition(q, s)));
  
  q = (Request)`delete Product p where p.name != "", p.review.id != ""`;
  println("PARTITIONING: <q>");
  println(partition2text(partition(q, s)));
  
  q = (Request) `insert @tv Product { name: "TV"}, Product {name: "Bla" }, Review { product: tv }`;
  println("PARTITIONING: <q>");
  println(partition2text(partition(q, s)));
  
  q = (Request) `update Product p where p.name == "TV" set {name: "Hallo"}`;
  println("PARTITIONING: <q>");
  println(partition2text(partition(q, s)));
  
}

/*

for object graphs: first flatten, then distribute, then for mongo unflatten to get containment back.

*/



Partitioning partition((Request)`delete <Binding b>`, Schema s)
  = partition((Request)`delete <Binding b> where true`, s);

Partitioning partition((Request)`delete <EId e> <VId x> where <{Expr ","}+ es>`, Schema s) {
  // even though the deletion is always local to a db, the where clauses
  // may cross database boundaries, this is the reason we need the two stage process
  // - first create a select query with the where clauses selecting the @id field
  //     - partition this
  //     - run through back-ends and recombine
  //  - then perform the deletion locally based on that working set
  //      i.e. delete <Binding b> where @id == ? 
  // script: select* delete(?)
  
  Partitioning result = [];
  selectReq = (Request)`from <EId e> <VId x> select <VId x>.@id where <{Expr ","}+ es>`;
  result += partition(selectReq, s); 
  
  if (<Place p, str entity> <- s.placement, "<e>" == entity) {
    result += [<p, (Request)`delete <EId e> <VId x> where <VId x>.@id == ?`>];
  }
  else {
    throw "Entity <e> is not in schema placement";
  } 
  
  return result;
}
   

Partitioning partition((Request)`update <EId eid> <VId vid> where <{Expr ","}+ es> set {<{KeyVal ","}* keyVals>}`, Schema s) {
  // we're gonna reject nested objects and lists in updates, because we cannot partition in advance:
  // the required inserts would commit to uuids; the inserts however, needs to be done
  // *per* object that will be updated (the result from the select); this means the whole
  // compiler logic needs to be pushed till after the select-result is known, which, at least for now, is too complex.
  
  // so the script for update will be
  // select update(?)
  
  if (/Obj _ := keyVals) {
    throw "Nested objects in update statements are unsupported";
  }  
  
  Partitioning result = [];
  selectReq = (Request)`from <EId eid> <VId vid> select <VId vid>.@id where <{Expr ","}+ es>`;
  result += partition(selectReq, s); 
  
  if (<Place p, str entity> <- s.placement, "<eid>" == entity) {
    result += [<p, (Request)`update <EId eid> <VId vid> where <VId vid>.@id == ? set {<{KeyVal ","}* keyVals>}`>];
  }
  else {
    throw "Entity <e> is not in schema placement";
  } 
  
  return result;
  
}

UUID lookup(VId vid, IdMap ids) {
  str x = "<vid>";
  if (<x, _, str u> <- ids) {
    return [UUID]"#<u>";
  }
  throw "No uuid for <vid>";
}
  

Partitioning partition(r:(Request)`insert <{Obj ","}* objs>`, Schema s) { 
  // script: insert+
  // flatten but only according to cross links
  // but for now, we completely flatten, and join things per database in a single insert
  // the mongodb driver can for instance, unflatten and nest again/
  
  list[Obj] objLst = flatten(objs);
  
  for (Obj obj <- objLst) {
    println("OBJ: <obj>");
  }
  //if (skipTopLevel) { 
  //  // this is a hack, to reuse insert partitioning for updates that contain nested object literals
  //  // the top-level is the one that will be updated, not inserted (and flatten is bottom-up, so it's the last element)
  //  objLst = objLst[0..-1];
  //}

  IdMap ids = makeIdMap(objLst);  
  
  insPerPlace = ();
  
  
  for (<Place p, str e> <- s.placement) {
    if (p notin insPerPlace) {
      insPerPlace[p] = (Request)`insert`;
    }
  
    for (x:(Obj)`@<VId vid> <EId eid> {<{KeyVal ","}* kvs>}` <- objLst, "<eid>" == e) {
      if ((Request)`insert <{Obj ","}* xs>` := insPerPlace[p]) {
      
        // resolve variables into uuids because vars may span across multiple inserts
        kvs2 = visit (kvs) {
          case (Expr)`<VId x>` => (Expr)`<UUID id>`
            when
              UUID id := lookup(x, ids)
        }
        
        UUID id = lookup(vid, ids);
        // NB: insert kvs2 here, in order to have variable refs resolved to uuids
        insPerPlace[p] = (Request)`insert <{Obj ","}* xs>, <EId eid> {@id: <UUID id>, <{KeyVal ","}* kvs2>}`;    
      }
      else {
        throw "Invalid insert in map";
      }
    }
  }
  
  for (Place p <- insPerPlace) {
    println("PP: <p> :: <insPerPlace[p]>");
  }
  
  return [ <p, insPerPlace[p]> | Place p <- insPerPlace, (Request)`insert` !:= insPerPlace[p] ];
}


Partitioning partition((Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs>`, Schema s) 
  = partition((Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where true`, s);


Partitioning partition(q:(Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ es>`, Schema s) {
  // script: select+ (where last one is recombine)
  
  map[str, str] env = ( "<x>": "<e>"  | (Binding)`<EId e> <VId x>` <- bs );
   
   
  int varId = 0;
  str newVar(str base) {
    str x = "<uncapitalize(base)>_<varId>";
    varId += 1;
    return x;
  }
  
  Partitioning result = [];
   
   // An end-result of this phase, is that we have a (unique?) variable for every entity...
   // Another invariant: in the combined result set  of the back-end queries
   // we have all entities available that are in the original binding set.
    
    
  for (Place p <- s.placement<0>) {
   
    // restrict bindings to bindings on the current place
    newBindings = [ b | Binding b <- bs, str e := "<b.entity>", <p, e> <- s.placement ];
    
    //println("Local bindings:");
    //for (Binding b <- newBindings) {
    //  println("  <b>");
    //}
    
    // kick out results that are not on the current db
    newResults = [ r | r:(Result)`<Expr re>` <- rs, isLocalTo(re, p, env, s) ];
    
    // need to add results for bindings that are local, but not in the result
    // TODO: this needs to be refined, it adds too many results in some cases... 
    newResults += [ (Result)`<VId x>` | (Binding)`<EId e> <VId x>` <- bs, isLocalTo((Expr)`<VId x>`, p, env, s) ]; 
    
    set[str] addedEntities = { e | Expr w <- es, <p, str e> <- dbPlacements(w, env, s) }
      + { e | (Result)`<Expr r>` <- rs, <p, str e> <- dbPlacements(r, env, s) };
      
    //println("Added entities: <addedEntities>");  
      
    rel[EId, VId] addedBindings = { <eid, x> | str e <- addedEntities,
      EId eid := [EId]e, !((Binding)`<EId eid> <VId _>` <- newBindings), VId x := [VId]newVar(e) };
    
    //for (<eid, vid> <- addedBindings) {
    //  println("Adding binding: <eid> <vid>");
    //}
    //
    // Add bindings for required cross-clause evaluation 
    newBindings += [ (Binding)`<EId eid> <VId x>` | <EId eid, VId x> <- addedBindings ]; 
    newResults += [ (Result)`<VId x>` | VId x <- addedBindings<1> ];

    // filter where clauses to expressions only local to this db.
    newWheres = [ e | Expr e <- es, isLocalTo(e, p, env, s) ];
    
    // project where expressions to the entities that are local to p
    // p.review.id != "" will become (newVar for entity Review).id != "")
    // for every a.b.c replace the path to the entity that's added with its var.
    // --> future work; currently these things would be evaluated at recombining stage
    
    
    
    if (newBindings == []) {
      // sometimes a back-end is not touched
      continue;
    } 
    
    Query newQ = buildQuery(newBindings, newResults, newWheres);
    result += [<p,(Request)`<Query newQ>`>];
  }
  
  // Recombination query
  
  //if (size(result) > 1) {
  //  newWheres = [ e | Expr e <- es, !isLocal(e, env, s) ];
  //
  //  Query recomb = buildQuery([ b | Binding b <- bs ], [ r | Result r <- rs ], newWheres); 
  //  result += [<<recombine(), "">, (Request)`<Query recomb>`>];
  //}

  return result;
}

Query buildQuery(list[Binding] bs, list[Result] rs, list[Expr] ws) {
  Binding b0 = bs[0];
  Result r0 = rs[0];
  Query q = (Query)`from <Binding b0> select <Result r0> where true`;
  
  int wherePos = 0;
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

str partition2text(Partitioning pr) {
  //str s = "ORIGINAL:\n  <pr[<typhon(), "">]>\n";
  //s += "PARTITIONING:\n";
  //for (Place p <- pr, p.db != typhon(), p.db != recombine()) {
  //  s += "  <p>: <pr[p]>\n";
  //}
  //s += "RECOMBINE:\n  <pr[<recombine(), "">]>";
  //return s;
  
  str s = "SCRIPT:\n";
  for (<Place p, Request r> <- pr) {
    s += "<p>: <r>\n";
  }
  return s;
}



