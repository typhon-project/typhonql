module lang::typhonql::relational::DML2SQL

import lang::typhonql::DML;
import lang::typhonql::util::Objects;

import lang::typhonql::relational::SQL;
import lang::typhonql::relational::Util;

import lang::typhonml::Util; // Schema
import lang::typhonml::TyphonML;


import IO;
import String;


/*
TODO
- complete expression interpreter




*/


list[SQLStat] dml2sql((Statement)`insert <{Obj ","}* objs>`, Schema schema)
  = insert2sql(makeIdMap(objList), objList, schema)
  when list[Obj] objList := flatten(objs);

list[SQLStat] insert2sql(IdMap idMap, list[Obj] objList, Schema schema) {
  // NB: this needs to be wrapped in a transaction  if we're gonna keep all the fk contraints and not null etc.

  list[SQLStat] result = [];
  
  list[str] attrColumns({KeyVal ","}* kvs, int i) {
    return [typhonId(idMap[i].entity)] + [ "<x>" | (KeyVal)`<Id x>: <Expr _>` <- kvs, 
      "<x>" in schema.attrs[idMap[i].entity]<0> ];
  }
  
  list[Value] attrValues({KeyVal ","}* kvs, int i) {
    return [text(idMap[i].uuid)] + [ evalExpr(e, idMap) | (KeyVal)`<Id x>: <Expr e>` <- kvs,
       "<x>" in schema.attrs[idMap[i].entity]<0>  ];
  }
  

  int i = 0;
  result += for ((Obj)`@<VId _> <EId entity> {<{KeyVal ","}* kvs>}` <- objList) {
    // we can alway append, because typhonId is always there (IOW: no empty inserts here).
    append \insert(tableName("<entity>"), attrColumns(kvs, i), attrValues(kvs, i));
    i += 1;
  }
  
  i = 0;
  result += outer: for ((Obj)`@<VId owner> <EId entity> {<{KeyVal ","}* kvs>}` <- objList) {
    // this assumes a VId is always an object ref, not an "ordinary" variable (do we have them?)
    for ((KeyVal)`<Id x>: <VId ref>` <- kvs) {
      str from = "<entity>";
      str fromRole = "<x>";
      str key = "<ref>";
      // this is why we should not do symmetric reduction of the schema here;
      // the user will be using any kind of relation, yet to map to physical, 
      // we use the canonical (the one that remains after doing symmetric reduction)
      // note: for junction tables it doesn't matter which one we use
      // because the it's a single insert, and the order of columns are explicitly specified
      
      if (<key, str to, str uuid> <- idMap) { // should always be true
        if (<from, _, fromRole, str toRole, _, to, true> <- schema.rels) {
          // found the canonical containment rel
          // but then reverse!!    
          append outer: update(tableName(to), [\set(fkName(toRole, fromRole), lit(text(idMap[i].uuid)))],
            [where([eq(column(tableName(to), typhonId(to)), lit(text(uuid)))])]);
        }
        else if (<to, _, str toRole, fromRole, _, from, true> <- schema.rels) {
          append outer: update(tableName(from), [\set(fkName(fromRole, toRole), lit(text(uuid)))],
            [where([eq(column(tableName(from), typhonId(from)), lit(text(idMap[i].uuid)))])]);
        }
        else if(<from, _, fromRole, str toRole, _, to, false> <- schema.rels)  { // a cross ref
          append outer: \insert(junctionTableName(from, fromRole, to, toRole)
                          , [junctionFkName(from, fromRole), junctionFkName(to, toRole)]
                          , [text(idMap[i].uuid), text(uuid)]);
        }
        else {
          throw "Reference <from>.<fromRole> not found in schema.";
        }
      }
    }
    i += 1;
  }
      
  return result;
}



// for now, just literals and VIds (NB: nested objects cannot occur anymore)
Value evalExpr((Expr)`<VId v>`, IdMap env) = text(uuid)
  when <str x, _, str uuid> <- env, x == "<v>";
 
// todo: unescaping (e.g. \" to ")!
Value evalExpr((Expr)`<Str s>`, IdMap env) = text("<s>"[1..-1]);

Value evalExpr((Expr)`<Int n>`, IdMap env) = integer(toInt("<n>"));

default Value evalExpr(Expr _, IdMap _) = null();


