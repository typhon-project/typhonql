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


alias InsertSpec = lrel[str table, tuple[list[str] cols, list[Value] vals] inserts];


InsertSpec objs2values({Obj ","}* objs, Schema schema) {
  list[Obj] objList = flatten(objs); 
  IdMap idMap = makeIdMap(objList);  

  list[str] attrColumns({KeyVal ","}* kvs, int i) {
    return [typhonId(idMap[i].entity)] + [ "<x>" | (KeyVal)`<Id x>: <Expr _>` <- kvs, 
      "<x>" in schema.attrs[idMap[i].entity]<0> ];
  }
  
  list[Value] attrValues({KeyVal ","}* kvs, int i) {
    return [text(idMap[i].uuid)] + [ evalExpr(e, idMap) | (KeyVal)`<Id x>: <Expr e>` <- kvs,
       "<x>" in schema.attrs[idMap[i].entity]<0>  ];
  }
  

  int i = 0;
  attrInserts = for ((Obj)`@<VId _> <EId entity> {<{KeyVal ","}* kvs>}` <- objList) {
    // we can alway append, because typhonId is always there (IOW: no empty inserts here).
    append <tableName("<entity>"), <attrColumns(kvs, i), attrValues(kvs, i)>>;
    i += 1;
  }
  
  int i = 0;
  refUpdatesOrInserts = for ((Obj)`@<VId owner> <EId entity> {<{KeyVal ","}* kvs>}` <- objList) {
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
      
      <cFrom, cFromCard, cFromRole, ignored, cToCard, cTo, contain> = findCanonical(from, fromRole, schema.rels);
      
      switch (<cFromCard, cToCard, contain>) {
	       case <one_many(), one_many(), true>: illegal(r);
	       case <one_many(), zero_many(), true>: illegal(r);
	       case <one_many(), zero_one(), true>: illegal(r);
	       
	       case <one_many(), \one(), true>: {
	         // update  <cTo> set <foreignKey> = <owner uuid> where typhonId = key
	         ;
	       }
	       
	       
	       case <zero_many(), one_many(), true>: illegal(r);
	       case <zero_many(), zero_many(), true>: illegal(r);
	       case <zero_many(), zero_one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, []);
	       
	       case <zero_many(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [notNull()]);
	
	       case <zero_one(), one_many(), true>: illegal(r);
	       case <zero_one(), zero_many(), true>: illegal(r);
	       case <zero_one(), zero_one(), true>: illegal(r);
	       case <zero_one(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [unique(), notNull()]);
	       
	       case <\one(), one_many(), true>: illegal(r);
	       case <\one(), zero_many(), true>: illegal(r);
	       case <\one(), zero_one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, []);
	       case <\one(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [unique(), notNull()]);
	       
	       // for now, we realize all cross refs using a junction table.
	       // so here it's not about updating but inserting.
	       case <_, _, false>: {
	         // insert into <junction> 
	        ;
	       }
	     }
	  }
	
    // p.m.       
    //       case <one_many(), one_many(), false>: ;
	//       case <one_many(), zero_many(), false>: ;
	//       case <one_many(), zero_one(), false>: ;
	//       case <one_many(), \one(), false>: ;
	//       
	//       
	//       case <zero_many(), one_many(), false>: ;
	//       case <zero_many(), zero_many(), false>: ;
	//       case <zero_many(), zero_one(), false>: ;
	//       case <zero_many(), \one(), false>: ;
	//
	//       case <zero_one(), one_many(), false>: ;
	//       case <zero_one(), zero_many(), false>: ;
	//       case <zero_one(), zero_one(), false>: ;
	//       case <zero_one(), \one(), false>: ;
	//       
	//       case <\one(), one_many(), false>: ; //unique left
	//       case <\one(), zero_many(), false>: ; //unique left
	//       case <\one(), zero_one(), false>: ; // unique left, 
	//       case <\one(), \one(), false>: ; // unique left, unique right
	       
    i += 1;
  }
  
  
  for (r:<str from, Cardinality fromCard, str fromRole, str toRole, Cardinality toCard, str to, bool contain> <- schema.rels) {
     switch (<fromCard, toCard, contain>) {
       case <one_many(), one_many(), true>: illegal(r);
       case <one_many(), zero_many(), true>: illegal(r);
       case <one_many(), zero_one(), true>: illegal(r);
       case <one_many(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, []); // ??? how to enforce one_many?
       
       
       case <zero_many(), one_many(), true>: illegal(r);
       case <zero_many(), zero_many(), true>: illegal(r);
       case <zero_many(), zero_one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, []);
       
       case <zero_many(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [notNull()]);

       case <zero_one(), one_many(), true>: illegal(r);
       case <zero_one(), zero_many(), true>: illegal(r);
       case <zero_one(), zero_one(), true>: illegal(r);
       case <zero_one(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [unique(), notNull()]);
       
       case <\one(), one_many(), true>: illegal(r);
       case <\one(), zero_many(), true>: illegal(r);
       case <\one(), zero_one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, []);
       case <\one(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [unique(), notNull()]);
       
       // for now, we realize all cross refs using a junction table.
       case <_, _, false>: addJunctionTable(from, fromRole, to, toRole);
       
       
     }
  } 
  
  return attrInserts;
  
}

// for now, just literals and VIds (NB: nested objects cannot occur anymore)
Value evalExpr((Expr)`<VId v>`, IdMap env) = text(uuid)
  when <str x, _, str uuid> <- env, x == "<v>";
 
// todo: unescaping (e.g. \" to ")!
Value evalExpr((Expr)`<Str s>`, IdMap env) = text("<s>"[1..-1]);

Value evalExpr((Expr)`<Int n>`, IdMap env) = integer(toInt("<n>"));

default Value evalExpr(Expr _, IdMap _) = null();


