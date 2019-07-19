module lang::typhonql::Native

import lang::typhonql::Bridge;
import lang::typhonql::TDBC;
import lang::typhonql::WorkingSet;
import lang::typhonql::util::Log;

import lang::typhonml::Util;

import lang::typhonql::relational::SQL;
import lang::typhonql::relational::SQL2Text;
import lang::typhonql::relational::Select2SQL;
import lang::typhonql::relational::SchemaToSQL;
import lang::typhonql::relational::DML2SQL;
import lang::typhonql::relational::Util;

import lang::typhonql::mongodb::DBCollection;
import lang::typhonql::mongodb::DML2Method;
import lang::typhonql::mongodb::Select2Find;


import String;




/*
The run* functions are the "interface" that needs to be implemented for every backend.
*/

/*
 * Booting a schema (NB: this will drop tables/collections if they already exist)
 */
 

void runSchema(p:<sql(), str db>, Schema s, Log log = noLog) {
  list[SQLStat] stats = schema2sql(s, p, s.placement[p], doForeignKeys = false);
  for (SQLStat stat <- stats) {
    log("[RUN-schema/sql/<db>] executing <pp(stat)>");
    executeUpdate(db, pp(stat));     
  }
}


void runSchema(p:<mongodb(), str db>, Schema s, Log log = noLog) {
  for (str entity <- s.placement[p]) {
    log("[RUN-schema/mongodb/<db>] creating collection <entity>");
    drop(db, entity);
    createCollection(db, entity);
  }
}


/*
 * Selection
 */

Doc dbObject2doc(object(list[Prop] props))
  = ( p.name: dbObject2doc(p.val) | Prop p <- props );

Doc dbObject2doc(array(list[DBObject] values))
  = [ dbObject2doc(v) | DBObject v <- values ];
  
Doc dbObject2doc(\value(value v)) = v;

// assumes flattening, so no nested docs in d
Entity doc2entity(str entity, Doc d)
  = <e, d["_id"], ( k: toWsValue(d[k]) | str k <- d, k != "_id" )>;

WorkingSet runQuery(<mongodb(), str db>, Request q, Schema s, Log log = noLog) {
  map[str, CollMethod] methods = compile2mongo(q, s);
  
  // NB: this is unwrapping the "legacy" mongo compiler, dbObject and CollMethod need to go.
  
  WorkingSet result = ();
  
  for (str entity <- methods) {
    CollMethod method = methods[entity];
    assert method is find;
    
    list[Doc] docs = find(db, entity, dbObject2doc(method.query));
    
    lrel[str, Doc] flattened = unnest(docs);
    
    for (<str e, Doc d> <- unnest(docs)) {
      result[e]?[] += doc2Entity(e, d);
    }
  }
  
  return result;
}

WorkingSet runQuery(<sql(), str db>, Request q, Schema s, Log log = noLog) {
  SQLStat stat = select2sql(q, s);
  ResultSet rs = executeQuery(db, pp(stat));
  
  WorkingSet ws = ();

  tuple[str,str] splitColName(str col) = <l, r>
    when [str l, str r] := split(".", col);
  
  for (Record r <- rs) {
    rel[str,str,value] values = { <e, f, r[col]> | str col <- r, <str e, str f> := splitColName(col) };
    
    for (str e <- values<0>) {
      ws[e]?[] += [ <e, r[typhonId(e)], (f: toWsValue(v) | <str f, value v> <- values[e], f != typhonId(e) )>];
    }
  }
  
  return ws;
}

/*
 * Insertion
 */


int runInsert(<sql(), str db>, Request ins, Schema s, Log log = noLog) {
  list[SQLStat] stats = insert2sql(ins, s);
  int affected = 0;
  for (SQLStat s <- stats) {
    affected += executeUpdate(db, pp(s), s);
  }
  return affected;
}

int runInsert(<mongodb(), str db>, Request ins, Schema s, Log log = noLog) {
  map[str, CollMethod] methods = compile2mongo(ins, s);
  for (str entity <- methods) {
    CollMethod method = methods[entity];
    assert method is \insert;
    for (DBObject obj <- method.documents) {
      insertOne(db, entity, dbObject2doc(obj));
    } 
  }
  return -1;
}

/*
 * Update
 */
 
int runUpdateById(<sql(), str db>, str entity, str uuid, {KeyVal ","}* kvs) {
  str tbl = tableName(entity);
  SQLStat upd = update(tbl,
      [ \set(columnName("<kv.name>", entity), lit(evalExpr(kv.\value))) | KeyVal kv <- kvs ],
      [where([equ(column(tbl, typhonId(entity)), lit(text(uuid)))])]);
  return executeUpdate(db, pp(upd)); 
}

int runUpdateById(<mongodb(), str db>, str entity, str uuid, {KeyVal ","}* kvs) {
  Doc doc = keyvals2update(kvs);
  UpdateResult result = updateOne(db, entity, ("_id": uuid), doc);
  return result.modifiedCount;
}


Doc keyvals2update({KeyVal ","}* kvs)
  = ("$set": ( "<k>": eval2value(v) | (KeyVal)`<Id k>: <Expr v>` <- kvs ));


// TODO: here we could allow nested objects if they are actually containments.
// TODO: if the ref here is containment, we should look it up first, and inline it.
value eval2value((Expr)`<UUID u>`) = "<u>"[1..];

value eval2value((Expr)`<Bool u>`) = ((Bool)`true` := u);

// todo unescaping
value eval2value((Expr)`<Str s>`) = "<s>"[1..-1];

value eval2value((Expr)`<Int n>`) = toInt("<n>");


default value eval2value(Expr e) {
  throw "Unsupported expression for conversion to value: <e>";
}


/*
 * Deletion
 */  
  

int runDeleteById(<mongodb(), str db>, str entity, str uuid) {
  deleteOne(db, entity, ("_id": uuid));
  return -1;
}

int runDeleteById(<sql(), str db>, str entity, str uuid) {
  str tbl = tableName("<entity>");
  SQLStat stat = delete(tbl, [where([equ(column(tbl, typhonId(entity)), lit(text(uuid)))])]);
  return executeUpdate(db, pp(stat));
}
