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
- Nested Objects for containment

*/


alias InsertSpec = lrel[str table, tuple[list[str] cols, list[Value] vals] inserts];


InsertSpec objs2values({Obj ","}* objs, Schema schema) {
  list[Obj] objList = flatten(objs); 
  IdMap idMap = makeIdMap(objList);  

  list[str] columns({KeyVal ","}* kvs, int i) {
    // todo: refs etc.
    return [typhonId(idMap[i].entity)] + [ "<x>" | (KeyVal)`<Id x>: <Expr _>` <- kvs ];
  }
  
  list[Value] values({KeyVal ","}* kvs, int i) {
    return [text(idMap[i].uuid)] + [ evalExpr(e, idMap) | (KeyVal)`<Id _>: <Expr e>` <- kvs ];
  }
  

  int i = 0;
  return for ((Obj)`@<VId _> <EId entity> {<{KeyVal ","}* kvs>}` <- objList) {
    append <tableName("<entity>"), <columns(kvs, i), values(kvs, i)>>;
    i += 1;
  }
}

// for now, just literals and VIds 
Value evalExpr((Expr)`<VId v>`, IdMap env) = text(uuid)
  when <str x, _, str uuid> <- env, x == "<v>";
 
// todo: unescaping (e.g. \" to ")!
Value evalExpr((Expr)`<Str s>`, IdMap env) = text("<s>"[1..-1]);

Value evalExpr((Expr)`<Int n>`, IdMap env) = integer(toInt("<n>"));

default Value evalExpr(Expr _, IdMap _) = null();


