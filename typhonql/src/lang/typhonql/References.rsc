module lang::typhonql::References

import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::Script;
import lang::typhonql::Session;
import lang::typhonql::TDBC;
import lang::typhonql::Order;

import lang::typhonql::relational::SQL;
import lang::typhonql::relational::Util;
import lang::typhonql::relational::SQL2Text;

import lang::typhonql::mongodb::DBCollection;


import IO;
import List;
import String;


// TODO: if junction tables are symmetric, i.e. normalized name order in junctionTableName
// then we don't have to swap arguments if maintaining the inverse at outside sql db.


list[Step] updateIntoJunctionSingle(str dbName, str from, str fromRole, str to, str toRole, SQLExpr src, SQLExpr trg, Bindings params) {
  return removeFromJunction(dbName, from, fromRole, to, toRole, src, params)
    + insertIntoJunctionMany(dbName, from, fromRole, to, toRole, src, [trg], params);
}

list[Step] updateIntoJunctionMany(str dbName, str from, str fromRole, str to, str toRole, SQLExpr src, list[SQLExpr] trgs, Bindings params) {
  return removeFromJunction(dbName, from, fromRole, to, toRole, src, params)
      + insertIntoJunction(dbName, from, fromRole, to, toRole, src, trgs, params);
}


list[Step] insertIntoJunction(str dbName, str from, str fromRole, str to, str toRole, SQLExpr src, list[SQLExpr] trgs, Bindings params) {
  str tbl = junctionTableName(from, fromRole, to, toRole);
  return  [ step(dbName, 
           sql(executeStatement(dbName, 
             pp(\insert(tbl
                  , [junctionFkName(from, fromRole), junctionFkName(to, toRole)]
                  , [src, trg])))), params) | SQLExpr trg <- trgs ];
}

list[Step] removeFromJunction(str dbName, str from, str fromRole, str to, str toRole, SQLExpr src, Bindings params) {
  str tbl = junctionTableName(from, fromRole, to, toRole);
  return  [ step(dbName, 
           sql(executeStatement(dbName, 
             pp(delete(tbl,
               [ where([equ(column(tbl, junctionFkName(from, fromRole)), src)]) ])))), params) ];
}

list[Step] removeFromJunction(str dbName, str from, str fromRole, str to, str toRole, SQLExpr src, list[SQLExpr] trgs, Bindings params) {
  str tbl = junctionTableName(from, fromRole, to, toRole);
  return  [ step(dbName, 
           sql(executeStatement(dbName, 
             pp(delete(tbl,
               [ where([equ(column(tbl, junctionFkName(from, fromRole)), src),
                    \in(column(tbl, junctionFkName(to, toRole)), [ trg.val | SQLExpr trg <- trgs ])]) ])))), params) ];
}

list[Step] cascadeViaJunction(str dbName, str from, str fromRole, str to, str toRole, SQLExpr src, Bindings params) {
  // src is a from
  str tbl = junctionTableName(from, fromRole, to, toRole);
  
  SQLStat stat = deleteJoining([tbl, tableName(to)],
    [ where([equ(column(tbl, junctionFkName(from, fromRole)), src),
         equ(column(tableName(to)), column(junctionFkName(to, toRole)))])]);
         
  return [step(dbName, sql(executeStatement(dbName, pp(stat))), params)];
}


list[Step] updateObjectPointer(str dbName, str coll, str role, Cardinality card, DBObject subject, DBObject target, Bindings params) {
    return [
      step(dbName, mongo( 
         findAndUpdateOne(dbName, coll,
          pp(object([<"_id", subject>])), 
          pp(object([<"$set", object([<role, target>])>])))), params)
          ];
}


list[Step] insertObjectPointer(str dbName, str coll, str role, Cardinality card, DBObject subject, DBObject trg, Bindings params) {
  if (card in {zero_many(), one_many()}) {
    return [
      step(dbName, mongo( 
         findAndUpdateOne(dbName, coll,
          pp(object([<"_id", subject>])), 
          pp(object([<"$addToSet", object([<role, array([ trg ])>])>])))), params)
          ];
  }
  return [
      step(dbName, mongo( 
         findAndUpdateOne(dbName, coll,
          pp(object([<"_id", subject>])), 
          pp(object([<"$set", object([<role, trg>])>])))), params)
          ];
  
}

list[Step] insertObjectPointers(str dbName, str coll, str role, Cardinality card, DBObject subject, list[DBObject] targets, Bindings params) {
    return [
      step(dbName, mongo( 
         findAndUpdateOne(dbName, coll,
          pp(object([<"_id", subject>])), 
          pp(object([<"$addToSet", object([<role, array([ trg | DBObject trg <- targets ])>])>])))), params)
          ];
}

list[Step] cascadeViaInverse(str dbName, str coll, str role, DBObject parent, Bindings params) {
  DBObject q = object([<role, parent>]);
  // todo: use deleteMany
  return [step(dbName, mongo(deleteMany(dbName, coll, pp(q))), params)];
}


list[Step] removeAllObjectPointers(str dbName, str coll, str role, Cardinality card, DBObject target, Bindings params) {
    return [
      step(dbName, mongo( 
         findAndUpdateMany(dbName, coll,
          pp(object([])), 
          pp(object([<"$pull", 
               object([<role, 
                 object([<"$in", array([ target ])>])>])>])))), params)
          ];
}

list[Step] removeObjectPointers(str dbName, str coll, str role, Cardinality card, DBObject subject, list[DBObject] targets, Bindings params) {
    return [
      step(dbName, mongo( 
         findAndUpdateOne(dbName, coll,
          pp(object([<"_id", subject>])), 
          pp(object([<"$pull", 
               object([<role, 
                 object([<"$in", array([ trg | DBObject trg <- targets ])>])>])>])))), params)
          ];
}

list[Step] deleteManyMongo(str dbName, str coll, list[DBObject] objs, Bindings params) {
  return [
    // todo: use deleteMany and $in
    step(dbName, mongo(
       deleteOne(dbName, coll, pp(object([<"_id", obj>])))), params)
       | DBObject obj <- objs ];
}
