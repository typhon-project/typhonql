module lang::typhonql::Run


import lang::typhonml::Util;

import lang::typhonql::WorkingSet;
import lang::typhonql::Native;
import lang::typhonql::Partition;
import lang::typhonql::TDBC;
import lang::typhonql::Eval;

import lang::typhonql::util::Log;


import Set;
import List;

value run(str src, Schema s, Log log = noLog) {
  Request req = [Request]src;
  return run(req, s, log = log);
}

void runSchema(Schema s, Log log = noLog) {
  for (Place p <- s.placement<0>) {
    log("[RUN-schema] executing schema for <p>");
    runSchema(p, s, log = log);
  }
}

value run((Request)`delete <EId e> <VId x>`, Schema s, Log log = noLog) 
  = run((Request)`delete <EId e> <VId x> where true`, s, log = log);


value run((Request)`delete <EId e> <VId x> where <{Expr ","}+ es>`, Schema s, Log log = noLog) {
  if (WorkingSet ws := run((Request)`from <EId e> <VId x> select <VId x>.@id where <{Expr ","}+ es>`, s, log = log)) {
    assert size(ws<0>) == 1: "multiple or zero entity types returned from select implied by delete";
  
    if (str entity <- ws, <Place p, entity> <- s.placement) {
      list[Entity] entities = ws[entity];
      for (<entity, str uuid, _> <- ws[entity]) {
        log("[RUN-delete] Deleting <entity> with id <uuid> from <p>");
        runDeleteById(p, entity, uuid);
      }
    }
  } 
  else {
    throw "Did not get workingset from select evaluation";
  }
  
  return -1;
  
  // TODO: cross-db containment cascade semantics

}

value run(r:(Request)`insert <{Obj ","}* objs>`, Schema s, Log log = noLog) {
  // NB: partitioning flattens the object list; and back-ends assume this
  Partitioning part = partition(r, s);
  int affected = 0;
  for (<Place p, Request q> <- part) {
    affected += runInsert(p, q, s);
  }
  return affected;
}


value run((Request)`update <Binding b> set {<{KeyVal ","}* kvs>}`, Schema schema, Log log = noLog) 
  = run((Request)`update <Binding b> where true set {<{KeyVal ","}* kvs>}`, schema, log = log);


value run((Request)`update <EId e> <VId x> where <{Expr ","}+ es> set {<{KeyVal ","}* kvs>}`, Schema schema, Log log = noLog) {
  // we're gonna reject nested objects and lists in updates for now, because we cannot partition in advance:
  // the required inserts would commit to uuids; the inserts however, needs to be done
  // *per* object that will be updated (the result from the select); this means the whole
  // compiler logic needs to be pushed till after the select-result is known, which, at least for now, is too complex.
  
  
  if (/Obj _ := kvs) {
    throw "Nested objects in update statements are unsupported";
  }  
  
  if (WorkingSet ws := run((Request)`from <EId eid> <VId vid> select <VId vid>.@id where <{Expr ","}+ es>`, s, log = log)) {
    assert size(ws<0>) == 1: "multiple or zero entity types returned from select implied by update";
  

    int affected = 0;  
    if (str entity <- ws, <Place p, entity> <- s.placement) {
      entities = ws[entity];
      for (<entity, str uuid, _> <- ws[entity]) {
        log("[RUN-update] Updating <entity> with id <uuid> from <p> with <kvs>");
        affected += runUpdateById(p, entity, uuid, kvs);
      }
    } 
    return affected;
  }
  else {
    throw "Did not get workingset from select evaluation";
  }
}

value run(q:(Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs>`, Schema s, Log log = noLog) 
  = run((Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where true`, s, log = log);
  

value run(q:(Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ es>`, Schema s, Log log = noLog) {
  Partitioning part = partition(q, s);
  WorkingSet ws = runPartitionedQueries(part, s, log = log);
  
  lrel[str, str] lenv = [ <"<x>", "<e>">  | (Binding)`<EId e> <VId x>` <- bs ];
  map[str, str] env = ( x: e  | <str x, str e> <- lenv );
  
  // TODO: initialize with types from result expressions.
  // before doing bigproduct.
  WorkingSet result = ( e: [] | <str x, str e> <- lenv );
  
  for (map[str, Entity] binding <- toBindings(lenv, bigProduct(lenv, ws))) {
    bool yes = ( true | it && truthy(eval(e, binding, ws)) | Expr e <- es, !isLocal(e, env, s) );  
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


WorkingSet runPartitionedQueries(Partitioning part, Schema s, Log log = noLog) 
  = ( () | it + runQuery(p, q, s, log = log) | <Place p, Request q> <- part );


