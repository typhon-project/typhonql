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


Turn this into a test case based on mydb.tml (it shows how nesting or inverse usage
lead to the same SQL):

rascal>ins = (Statement)`insert @tv Product { name: "TV", review: Review {  } }`;
Statement: (Statement) `insert @tv Product { name: "TV", review: Review {  } }`
rascal>println(pp(dml2sql(ins, s)))
OBJ: @obj_0 Review {}
OBJ: @tv Product { name: "TV", review: obj_0 }
insert into `Review_entity` (_typhon_id) values ('f05eeb86-ae87-4cb5-910c-bd27373013de');

insert into `Product_entity` (_typhon_id, name) values ('e2612f93-87e8-4d44-a2d5-0bebded8c6ca', 'TV');

update `Review_entity` set `product_id` = 'e2612f93-87e8-4d44-a2d5-0bebded8c6ca'
where (`Review_entity`.`_typhon_id`) = ('f05eeb86-ae87-4cb5-910c-bd27373013de')
ok
rascal>ins = (Statement)`insert @tv Product { name: "TV"}, Review { product: tv }`;
Statement: (Statement) `insert @tv Product { name: "TV"}, Review { product: tv }`
rascal>println(pp(dml2sql(ins, s)))
OBJ: @obj_0 Review {product: tv}
OBJ: @tv Product { name: "TV"}
insert into `Review_entity` (_typhon_id) values ('b0ce86a7-c2a6-418c-be09-c4f546ce4994');

insert into `Product_entity` (_typhon_id, name) values ('a1e20762-4eee-40d6-99d6-02f359700313', 'TV');

update `Review_entity` set `product_id` = 'a1e20762-4eee-40d6-99d6-02f359700313'
where (`Review_entity`.`_typhon_id`) = ('b0ce86a7-c2a6-418c-be09-c4f546ce4994')

*/


list[SQLStat] dml2sql((Statement)`insert <{Obj ","}* objs>`, Schema schema)
  = insert2sql(makeIdMap(objList), objList, schema)
  when list[Obj] objList := flatten(objs);

list[SQLStat] insert2sql(IdMap idMap, list[Obj] objList, Schema schema) {
  list[SQLStat] result = [];
  
  for (Obj obj <- objList) {
    println("OBJ: <obj>");
  }
 
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
        if (<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, to, true> <- schema.rels) {
          // found the canonical containment rel
          // but then reverse!!    
          append outer: update(tableName(to), [\set(fkName(toRole, fromRole), lit(text(idMap[i].uuid)))],
            [where([eq(column(tableName(to), typhonId(to)), lit(text(uuid)))])]);
        }
        else if (<to, Cardinality toCard, str toRole, fromRole, Cardinality fromCard, from, true> <- schema.rels) {
          append outer: update(tableName(from), [\set(fkName(fromRole, toRole), lit(text(uuid)))],
            [where([eq(column(tableName(from), typhonId(from)), lit(text(idMap[i].uuid)))])]);
        }
        else { // a cross ref
          ;
        }
      }
    }
    i += 1;
  }
      
  return result;
}


//InsertSpec objs2values({Obj ","}* objs, Schema schema) {
//  list[Obj] objList = flatten(objs); 
//  IdMap idMap = makeIdMap(objList);  
//
//  list[str] attrColumns({KeyVal ","}* kvs, int i) {
//    return [typhonId(idMap[i].entity)] + [ "<x>" | (KeyVal)`<Id x>: <Expr _>` <- kvs, 
//      "<x>" in schema.attrs[idMap[i].entity]<0> ];
//  }
//  
//  list[Value] attrValues({KeyVal ","}* kvs, int i) {
//    return [text(idMap[i].uuid)] + [ evalExpr(e, idMap) | (KeyVal)`<Id x>: <Expr e>` <- kvs,
//       "<x>" in schema.attrs[idMap[i].entity]<0>  ];
//  }
//  
//
//  int i = 0;
//  attrInserts = for ((Obj)`@<VId _> <EId entity> {<{KeyVal ","}* kvs>}` <- objList) {
//    // we can alway append, because typhonId is always there (IOW: no empty inserts here).
//    append <tableName("<entity>"), <attrColumns(kvs, i), attrValues(kvs, i)>>;
//    i += 1;
//  }
//  
//  int i = 0;
//  refUpdatesOrInserts = for ((Obj)`@<VId owner> <EId entity> {<{KeyVal ","}* kvs>}` <- objList) {
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
//      <cFrom, cFromCard, cFromRole, ignored, cToCard, cTo, contain> = findCanonical(from, fromRole, schema.rels);
//      
//      switch (<cFromCard, cToCard, contain>) {
//	       case <one_many(), one_many(), true>: illegal(r);
//	       case <one_many(), zero_many(), true>: illegal(r);
//	       case <one_many(), zero_one(), true>: illegal(r);
//	       
//	       case <one_many(), \one(), true>: {
//	         // update  <cTo> set <foreignKey> = <owner uuid> where typhonId = key
//	         ;
//	       }
//	       
//	       
//	       case <zero_many(), one_many(), true>: illegal(r);
//	       case <zero_many(), zero_many(), true>: illegal(r);
//	       case <zero_many(), zero_one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, []);
//	       
//	       case <zero_many(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [notNull()]);
//	
//	       case <zero_one(), one_many(), true>: illegal(r);
//	       case <zero_one(), zero_many(), true>: illegal(r);
//	       case <zero_one(), zero_one(), true>: illegal(r);
//	       case <zero_one(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [unique(), notNull()]);
//	       
//	       case <\one(), one_many(), true>: illegal(r);
//	       case <\one(), zero_many(), true>: illegal(r);
//	       case <\one(), zero_one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, []);
//	       case <\one(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [unique(), notNull()]);
//	       
//	       // for now, we realize all cross refs using a junction table.
//	       // so here it's not about updating but inserting.
//	       case <_, _, false>: {
//	         // insert into <junction> 
//	        ;
//	       }
//	     }
//	  }
//	
//    // p.m.       
//    //       case <one_many(), one_many(), false>: ;
//	//       case <one_many(), zero_many(), false>: ;
//	//       case <one_many(), zero_one(), false>: ;
//	//       case <one_many(), \one(), false>: ;
//	//       
//	//       
//	//       case <zero_many(), one_many(), false>: ;
//	//       case <zero_many(), zero_many(), false>: ;
//	//       case <zero_many(), zero_one(), false>: ;
//	//       case <zero_many(), \one(), false>: ;
//	//
//	//       case <zero_one(), one_many(), false>: ;
//	//       case <zero_one(), zero_many(), false>: ;
//	//       case <zero_one(), zero_one(), false>: ;
//	//       case <zero_one(), \one(), false>: ;
//	//       
//	//       case <\one(), one_many(), false>: ; //unique left
//	//       case <\one(), zero_many(), false>: ; //unique left
//	//       case <\one(), zero_one(), false>: ; // unique left, 
//	//       case <\one(), \one(), false>: ; // unique left, unique right
//	       
//    i += 1;
//  }
//  
//  
//  for (r:<str from, Cardinality fromCard, str fromRole, str toRole, Cardinality toCard, str to, bool contain> <- schema.rels) {
//     switch (<fromCard, toCard, contain>) {
//       case <one_many(), one_many(), true>: illegal(r);
//       case <one_many(), zero_many(), true>: illegal(r);
//       case <one_many(), zero_one(), true>: illegal(r);
//       case <one_many(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, []); // ??? how to enforce one_many?
//       
//       
//       case <zero_many(), one_many(), true>: illegal(r);
//       case <zero_many(), zero_many(), true>: illegal(r);
//       case <zero_many(), zero_one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, []);
//       
//       case <zero_many(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [notNull()]);
//
//       case <zero_one(), one_many(), true>: illegal(r);
//       case <zero_one(), zero_many(), true>: illegal(r);
//       case <zero_one(), zero_one(), true>: illegal(r);
//       case <zero_one(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [unique(), notNull()]);
//       
//       case <\one(), one_many(), true>: illegal(r);
//       case <\one(), zero_many(), true>: illegal(r);
//       case <\one(), zero_one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, []);
//       case <\one(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [unique(), notNull()]);
//       
//       // for now, we realize all cross refs using a junction table.
//       case <_, _, false>: addJunctionTable(from, fromRole, to, toRole);
//       
//       
//     }
//  } 
//  
//  return attrInserts;
//  
//}

// for now, just literals and VIds (NB: nested objects cannot occur anymore)
Value evalExpr((Expr)`<VId v>`, IdMap env) = text(uuid)
  when <str x, _, str uuid> <- env, x == "<v>";
 
// todo: unescaping (e.g. \" to ")!
Value evalExpr((Expr)`<Str s>`, IdMap env) = text("<s>"[1..-1]);

Value evalExpr((Expr)`<Int n>`, IdMap env) = integer(toInt("<n>"));

default Value evalExpr(Expr _, IdMap _) = null();


