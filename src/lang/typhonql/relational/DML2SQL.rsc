module lang::typhonql::relational::DML2SQL

import lang::typhonql::TDBC;
import lang::typhonql::util::Objects;

import lang::typhonql::relational::SQL;
import lang::typhonql::relational::Select2SQL;
import lang::typhonql::relational::Util;

import lang::typhonml::Util; // Schema
import lang::typhonml::TyphonML;


import IO;
import String;

/*
 * Todo: make bindings optional
 */


list[SQLStat] compile2sql(s:(Request)`insert <{Obj ","}* _>`, Schema m)
  = insert2sql(s, m);

list[SQLStat] compile2sql(s:(Request)`delete <Binding _>`, Schema m)
  = delete2sql(s, m);

list[SQLStat] compile2sql(s:(Request)`delete <Binding _> <Where _>`, Schema m)
  = delete2sql(s, m);

list[SQLStat] compile2sql(s:(Request)`update <Binding _> set {<{KeyVal ","}* _>}`, Schema m)
  = update2sql(s, m);

list[SQLStat] compile2sql(s:(Request)`update <Binding _> <Where _> set {<{KeyVal ","}* _>}`, Schema m)
  = update2sql(s, m);



/*
 * Delete
 */
 
 
list[SQLStat] delete2sql((Request)`delete <Binding b>`, Schema schema)
  = delete2sql((Statement)`delete <Binding b> where true`, schema);

list[SQLStat] delete2sql((Request)`delete <EId e> <VId x> where <{Expr ","}+ es>`, Schema schema) {
  q = select2sql((Query)`from <EId e> <VId x> select "" where <{Expr ","}+ es>`, schema);
  
  // TODO: deleting stuff from junction tables explicitly?
  // (for now contained stuff is dealt with by cascade, similar for junctions)
  
  return [delete(tableName("<e>"), q.clauses)];
}


/*
 * Update
 */

  
list[SQLStat] update2sql((Request)`update <Binding b> set {<{KeyVal ","}* kvs>}`, Schema schema) 
  = update2sql((Request)`update <Binding b> where true set {<{KeyVal ","}* kvs>}`, schema);


list[SQLStat] update2sql((Request)`update <EId e> <VId x> where <{Expr ","}+ es> set {<{KeyVal ","}* kvs>}`, Schema schema) {
  q = select2sql((Query)`from <EId e> <VId x> select "" where <{Expr ","}+ es>`, schema);
  
  // TODO: assigning a ref to an owned thing needs updating the kid table.
  // and similar for cross references.
  
  return [update(tableName("<e>"),
      [ \set(columnName(kv, "<e>"), lit(evalExpr(kv.\value))) | KeyVal kv <- kvs ],
      q.clauses)];
}

str columnName((KeyVal)`<Id x>: <Expr _>`, str entity) = columnName("<x>", entity); 

str columnName((KeyVal)`@id: <Expr _>`, str entity) = typhonId(entity); 

Value evalKeyVal((KeyVal)`<Id _>: <Expr e>`) = evalExpr(e);

Value evalKeyVal((KeyVal)`@id: <Expr e>`) = evalExpr(e);

bool isAttr((KeyVal)`<Id x>: <Expr _>`, str e, Schema s) = <e, "<x>", _> <- s.attrs;

bool isAttr((KeyVal)`@id: <Expr _>`, str _, Schema _) = true;


  
/*
 * Insert (NB: this assumes partitioning has happened, so all ids are assigned to @id and refs resolve to them)
 */  

list[SQLStat] insert2sql((Request)`insert <{Obj ","}* objs>`, Schema schema) {
  // NB: this needs to be wrapped in a transaction  if we're gonna keep all the fk contraints and not null etc.

  list[str] aCols({KeyVal ","}* kvs, str entity) 
    = [ columnName(kv, entity) | KeyVal kv  <- kvs, isAttr(kv, entity, schema) ];
  
  list[Value] aVals({KeyVal ","}* kvs, str entity) 
    = [ evalKeyVal(kv) | KeyVal kv <- kvs, isAttr(kv, entity, schema) ];

  result = [ \insert(tableName("<e>"), aCols(kvs, "<e>"), aVals(kvs, "<e>")) | (Obj)`<EId e> {<{KeyVal ","}* kvs>}` <- objs ]; 
  
  
  
  result += outer: for ((Obj)`<EId entity> {<{KeyVal ","}* kvs>}` <- objs) {
    str myUUID = lookupId(kvs);
    // this assumes a VId is always an object ref, not an "ordinary" variable (do we have them?)
    
    // for all non-attr reference bindings
    for ((KeyVal)`<Id x>: <UUID ref>` <- kvs) {
      str from = "<entity>";
      str fromRole = "<x>";
      str uuid = "<ref>"[1..];
      
      // this is why we should not do symmetric reduction of the schema here;
      // the user will be using any kind of relation, yet to map to physical, 
      // we use the canonical (the one that remains after doing symmetric reduction)
      // note: for junction tables it doesn't matter which one we use
      // because the it's a single insert, and the order of columns are explicitly specified
      
      if (<from, _, fromRole, str toRole, _, to, true> <- schema.rels) {
        // found the canonical containment rel
        // but then reverse!!    
        append outer: update(tableName(to), [\set(fkName(from, to, fromRole), lit(text(myUUID)))],
            [where([equ(column(tableName(to), typhonId(to)), lit(text(uuid)))])]);
      }
      else if (<to, _, str toRole, fromRole, _, from, true> <- schema.rels) {
        append outer: update(tableName(from), [\set(fkName(from, to, toRole), lit(text(uuid)))],
          [where([equ(column(tableName(from), typhonId(from)), lit(text(myUUID)))])]);
      }
      else if(<from, _, fromRole, str toRole, _, to, false> <- schema.rels)  { // a cross ref
        append outer: \insert(junctionTableName(from, fromRole, to, toRole)
                        , [junctionFkName(from, fromRole), junctionFkName(to, toRole)]
                        , [text(myUUID), text(uuid)]);
      }
      else {
        throw "Reference <from>.<fromRole> not found in schema.";
      }
    }
  }
      
  return result;
}


//list[SQLStat] insert2sql((Request)`insert <{Obj ","}* objs>`, Schema schema)
//  = insert2sql(makeIdMap(objList), objList, schema)
//  when list[Obj] objList := flatten(objs, doFlattening=true);
//  
//
//bool hasAssignedId({KeyVal ","}* kvs) = (KeyVal)`@id: <Expr _>` <- kvs;
//
//list[SQLStat] insert2sql(IdMap idMap, list[Obj] objList, Schema schema) {
//  // NB: this needs to be wrapped in a transaction  if we're gonna keep all the fk contraints and not null etc.
//
//  list[SQLStat] result = [];
//  
//  list[str] attrColumns({KeyVal ","}* kvs, int i) {
//    e = idMap[i].entity;
//    return [typhonId(e) | !hasAssignedId(kvs) ] + [ columnName("<x>", e) | (KeyVal)`<Id x>: <Expr _>` <- kvs, 
//      "<x>" in schema.attrs[e]<0> ];
//  }
//  
//  list[Value] attrValues({KeyVal ","}* kvs, int i) {
//    return [text(idMap[i].uuid) | !hasAssignedId(kvs) ] + [ evalExpr(e, idMap) | (KeyVal)`<Id x>: <Expr e>` <- kvs,
//       "<x>" in schema.attrs[idMap[i].entity]<0>  ];
//  }
//  
//
//  int i = 0;
//  result += for ((Obj)`@<VId _> <EId entity> {<{KeyVal ","}* kvs>}` <- objList) {
//    // we can alway append, because typhonId is always there (IOW: no empty inserts here).
//    append \insert(tableName("<entity>"), attrColumns(kvs, i), attrValues(kvs, i));
//    i += 1;
//  }
//  
//  i = 0;
//  result += outer: for ((Obj)`@<VId owner> <EId entity> {<{KeyVal ","}* kvs>}` <- objList) {
//    // this assumes a VId is always an object ref, not an "ordinary" variable (do we have them?)
//    for ((KeyVal)`<Id x>: <VId ref>` <- kvs) {
//      str from = "<entity>";
//      str fromRole = "<x>";
//      str key = "<ref>";
//      // this is why we should not do symmetric reduction of the schema here;
//      // the user will be using any kind of relation, yet to map to physical, 
//      // we use the canonical (the one that remains after doing symmetric reduction)
//      // note: for junction tables it doesn't matter which one we use
//      // because the it's a single insert, and the order of columns are explicitly specified
//      
//      if (<key, str to, str uuid> <- idMap) { // should always be true
//        if (<from, _, fromRole, str toRole, _, to, true> <- schema.rels) {
//          // found the canonical containment rel
//          // but then reverse!!    
//          append outer: update(tableName(to), [\set(fkName(from, to, fromRole), lit(text(idMap[i].uuid)))],
//            [where([equ(column(tableName(to), typhonId(to)), lit(text(uuid)))])]);
//        }
//        else if (<to, _, str toRole, fromRole, _, from, true> <- schema.rels) {
//          append outer: update(tableName(from), [\set(fkName(from, to, toRole), lit(text(uuid)))],
//            [where([equ(column(tableName(from), typhonId(from)), lit(text(idMap[i].uuid)))])]);
//        }
//        else if(<from, _, fromRole, str toRole, _, to, false> <- schema.rels)  { // a cross ref
//          append outer: \insert(junctionTableName(from, fromRole, to, toRole)
//                          , [junctionFkName(from, fromRole), junctionFkName(to, toRole)]
//                          , [text(idMap[i].uuid), text(uuid)]);
//        }
//        else {
//          throw "Reference <from>.<fromRole> not found in schema.";
//        }
//      }
//    }
//    i += 1;
//  }
//      
//  return result;
//}



Value evalExpr((Expr)`<VId v>`) { throw "Variable still in expression"; }
 
// todo: unescaping (e.g. \" to ")!
Value evalExpr((Expr)`<Str s>`) = text("<s>"[1..-1]);

Value evalExpr((Expr)`<Int n>`) = integer(toInt("<n>"));

Value evalExpr((Expr)`<Bool b>`) = boolean("<b>" == true);

// cannot happen, because is a ref
//Value evalExpr((Expr)`<UUID u>`) = text("<u>"[1..]);

default Value evalExpr(Expr _) = null();


