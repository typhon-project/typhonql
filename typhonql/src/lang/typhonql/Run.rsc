module lang::typhonql::Run


import lang::typhonml::Util;
import lang::typhonml::TyphonML;

import lang::typhonql::WorkingSet;
import lang::typhonql::Native;
import lang::typhonql::Partition;
import lang::typhonql::TDBC;
import lang::typhonql::Eval;
import lang::typhonql::Closure;

import lang::typhonql::util::Log;

import lang::typhonml::XMIReader;


import IO;
import Set;
import List;

/*
	data Schema
	  = schema(Rels rels, Attrs attrs, Placement placement = {}, map[str, value] config = ());


	alias Rel = tuple[str from, Cardinality fromCard, str fromRole, str toRole, Cardinality toCard, str to, bool containment];
	alias Rels = set[Rel];
	alias Attrs = rel[str from, str name, str \type];
	
	data Cardinality
  		= one_many()
  		| zero_many()
  		| zero_one()
  		| \one()
  		;
  		
  	data DB = mongodb() | sql() | hyperj() | recombine() | unknown() | typhon();

	alias Place = tuple[DB db, str name];

	alias Placement = rel[Place place, str entity];
	
	*/
	
alias JavaFriendlySchema = tuple[rel[str from, str fromCard, str fromRole, str toRole, str toCard, str to, bool containment] rels, 
	rel[str from, str name, str \type] attrs, rel[str dbEngineType, str dbName, str entity] placement];

Rel toSchemaRel(<str from, str fromCard, str fromRole, str toRole, str toCard, str to, bool containment>)
	= <from, toCardinality(fromCard), fromRole, toRole, toCardinality(toCard), to, containment>;
	
Cardinality toCardinality("ONE_MANY") = one_many();
Cardinality toCardinality("ZERO_MANY") = zero_many();
Cardinality toCardinality("ZERO_ONE") = zero_one();
Cardinality toCardinality("ONE") = \one();
default Cardinality toCardinality(str card) {
	throw "Unknown cardinality: <card>";
} 	
	
DB toDB("documentdb") = mongodb();
DB toDB("relationaldb") = sql();
default DB toDB(str db) {
	throw "Unknown database type: <db>";
} 	
	
tuple[Place, str] toSchemaPlacementItem(<str dbEngineType, str dbName, str entity>) 
	= <<toDB(dbEngineType), dbName>, entity>;

Schema toSchema(JavaFriendlySchema sch)
	= schema(rels, sch.attrs, placement = placement)
	when rels:= {toSchemaRel(r) | r <- sch.rels},
		 placement := {toSchemaPlacementItem(p) | p <- sch.placement};
		

value run(str src, str polystoreId, JavaFriendlySchema s, Log log = noLog) {
	Request req = [Request]src;
	Schema sch = toSchema(s);
 	return run(req, polystoreId, sch, log = noLog);
}

value run(str src, str polystoreId, Schema s, Log log = noLog) {
  Request req = [Request]src;
  return run(req, polystoreId, s, log = log);
}


value run(str src, str polystoreId, str xmiString, Log log = noLog) {
  Model m = xmiString2Model(xmiString);
  Schema s = model2schema(m);
  Request req = [Request]src;
  return run(req, polystoreId, s, log = log);
}


WorkingSet dumpDB(str polystoreId, Schema s) {
  //WorkingSet ws = ( e : [] | <_, str e> <- s.placement );
  
  WorkingSet ws = ();
  
  for (<Place p, str e> <- s.placement) {
  	println(p);
    ws += runGetEntities(p, e, polystoreId, s);
  }
  
  return ws;
}

void runSchema(str polystoreId, str xmiString, Log log = noLog) {
  Model m = xmiString2Model(xmiString);
  Schema s = model2schema(m);
  runSchema(polystoreId, s, log = log);
}


value run(r:(Request)`create <EId eId> at <Id dbName>`, str polystoreId, Schema s, Log log = noLog) {
	 for (p:<db, name> <- s.placement<0>, name == "<dbName>") {
	 	runCreateEntity(p, polystoreId, "<eId>", s, log = log);
	 }
	 return 1;
}

value run(r:(Request)`create <EId eId>.<Id attribute> : <Type ty>`, str polystoreId, Schema s, Log log = noLog) {
	 for (p:<db, name> <- s.placement<0>, name == "<dbName>") {
	 	runCreateAttribute(p, polystoreId, "<eId>", "<attribute>", "<ty>", s, log = log);
	 }
	 return 1;
}

void runSchema(str polystoreId, Schema s, Log log = noLog) {
	for (Place p <- s.placement<0>) {
    	log("[RUN-schema] executing schema for <p>");
    	runSchema(p, polystoreId, s, log = log);
  	}
}

value run((Request)`delete <EId e> <VId x>`, str polystoreId, Schema s, Log log = noLog) 
  = run((Request)`delete <EId e> <VId x> where true`, polystoreId, s, log = log);


value run((Request)`delete <EId e> <VId x> where <{Expr ","}+ es>`, str polystoreId, Schema s, Log log = noLog) {
  if (WorkingSet ws := run((Request)`from <EId e> <VId x> select <VId x>.@id where <{Expr ","}+ es>`, polystoreId, s, log = log)) {
    assert size(ws<0>) == 1: "multiple or zero entity types returned from select implied by delete: <ws>";
  
    if (str entity <- ws, <Place p, entity> <- s.placement) {
      list[Entity] entities = ws[entity];
      for (<entity, str uuid, _> <- ws[entity]) {
        log("[RUN-delete] Deleting <entity> with id <uuid> from <p>");
        runDeleteById(p, polystoreId, entity, uuid);
      }
    }
  } 
  else {
    throw "Did not get workingset from select evaluation";
  }
  
  return -1;
  
  // TODO: cross-db containment cascade semantics

}

value run(r:(Request)`insert <{Obj ","}* objs>`, str polystoreId, Schema s, Log log = noLog) {
  // NB: partitioning flattens the object list; and back-ends assume this
  Partitioning part = partition(r, s);
  int affected = 0;
  for (<Place p, Request q> <- part) {
    affected += runInsert(p, q, polystoreId, s);
  }
  return affected;
}


value run((Request)`update <Binding b> set {<{KeyVal ","}* kvs>}`, str polystoreId, Schema s, Log log = noLog) 
  = run((Request)`update <Binding b> where true set {<{KeyVal ","}* kvs>}`, polystoreId, s, log = log);


value run((Request)`update <EId eid> <VId vid> where <{Expr ","}+ es> set {<{KeyVal ","}* kvs>}`, str polystoreId, Schema s, Log log = noLog) {
  // we're gonna reject nested objects and lists in updates for now, because we cannot partition in advance:
  // the required inserts would commit to uuids; the inserts however, needs to be done
  // *per* object that will be updated (the result from the select); this means the whole
  // compiler logic needs to be pushed till after the select-result is known, which, at least for now, is too complex.
  
  
  if (/Obj _ := kvs) {
    throw "Nested objects in update statements are unsupported";
  }  
  
  if (WorkingSet ws := run((Request)`from <EId eid> <VId vid> select <VId vid>.@id where <{Expr ","}+ es>`, polystoreId, s, log = log)) {
    assert size(ws<0>) == 1: "multiple or zero entity types returned from select implied by update";
  

    int affected = 0;  
    if (str entity <- ws, <Place p, entity> <- s.placement) {
      list[Entity] entities = ws[entity];
      for (<entity, str uuid, _> <- ws[entity]) {
        log("[RUN-update] Updating <entity> with id <uuid> from <p> with <kvs>");
        affected += runUpdateById(p, polystoreId, entity, uuid, kvs);
      }
    } 
    return affected;
  }
  else {
    throw "Did not get workingset from select evaluation";
  }
}

value run(q:(Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs>`, str polystoreId, Schema s, Log log = noLog) 
  = run((Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where true`, polystoreId, s, log = log);
  

value run(q:(Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ es>`, str polystoreId, Schema s, Log log = noLog) {
  rel[Place, str] cl = closure(q, s);
  
  WorkingSet ws = ( e : [] | <_, str e> <- cl );
  
  for (<Place p, str e> <- cl) {
    ws[e] += runGetEntities(p, e, polystoreId, s)[e];
  }
  
  lrel[str, str] lenv = [ <"<x>", "<e>">  | (Binding)`<EId e> <VId x>` <- bs ];
  map[str, str] env = ( x: e  | <str x, str e> <- lenv );
  
  
  WorkingSet result = ( inferEntity(e, env, s): [] | (Result)`<Expr e>` <- rs );
  
  for (map[str, Entity] binding <- toBindings(lenv, bigProduct(lenv, ws))) {
    bool yes = ( true | it && truthy(eval(e, binding, ws)) | Expr e <- es ); 

    for (yes, (Result)`<Expr re>` <- rs) {
      Entity r = evalResult(re, binding, ws);
      log("[RUN-query] Adding <r> to final result for <re>");
      if (r.name notin result) {
        result[r.name] = [];
      }
      result[r.name] += [r];
    }
  }

  return result;  

}


str inferEntity((Expr)`<VId x>`, map[str, str] env, Schema s)
  = env["<x>"];
  
str inferEntity((Expr)`<VId x>.@id`, map[str, str] env, Schema s)
  = env["<x>"];
  

str inferEntity((Expr)`<VId x>.<{Id "."}+ xs>`, map[str, str] env, Schema s)
  = navigateTo(xs, env["<x>"], s);

str navigateTo({Id "."}+ xs, str from, Schema s) {
  str cur = from;
  
  for (Id x <- xs) {
    str fld = "<x>";
    if (<cur, fld, _> <- s.attrs) {
      return cur;
    }
    if (<cur, _, fld, _, _, str to, _> <- schema.rels) {
      cur = to;
    }
  }
  return cur;
}



WorkingSet runPartitionedQueries(Partitioning part, str polystoreId, Schema s, Log log = noLog) 
  = ( () | it + runQuery(p, q, polystoreId, s, log = log) | <Place p, Request q> <- part );


