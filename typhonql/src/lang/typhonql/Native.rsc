module lang::typhonql::Native

import lang::typhonql::Bridge;
import lang::typhonql::TDBC;
import lang::typhonql::WorkingSet;
import lang::typhonql::util::Log;

import lang::typhonml::TyphonML;
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
import List;
import IO;




/*
The run* functions are the "interface" that needs to be implemented for every backend.
For every back-end we should have the following functions:

- runSchema: initializing a database with the schema entities
- runGetEntities: getting all entities of a certain type from a database
- runInsert: inserting objects into a database
- runUpdateById: updating a single entity identified by its Typhon Id
- runDeleteById: deleting a single entity identified by its Typhon Id
- [TODO] runQuery: running a TyphonQL query natively, after partitioning

*/

/*
 * Booting a schema (NB: this will drop tables/collections if they already exist)
 */
 

void runSchema(p:<sql(), str db>, str polystoreId, Schema s, Log log = noLog) {
  list[SQLStat] stats = schema2sql(s, p, s.placement[p], doForeignKeys = false);
  for (SQLStat stat <- stats) {
    log("[RUN-schema/sql/<db>] executing <pp(stat)>");
    executeUpdate(polystoreId, db, pp(stat));     
  }
}


void runSchema(p:<mongodb(), str db>, str polystoreId, Schema s, Log log = noLog) {
  for (str entity <- s.placement[p]) {
    log("[RUN-schema/mongodb/<db>] creating collection <entity>");
    drop(polystoreId, db, entity);
    createCollection(polystoreId, db, entity);
  }
}


/*
 * Selection
 */
 
WorkingSet runGetEntities(<sql(), str db>, str entity, str polystoreId, Schema s) {
  str tbl = tableName(entity);
  
  SQLStat q = select( [ column("x", typhonId(entity)) ] 
     + [ column("x", columnName(fld, entity)) | <entity, str fld, _> <- s.attrs ]
    , [as(tbl, "x")], []);
    
  ResultSet rs = executeQuery(polystoreId, db, pp(q));
  
  map[str, str] col2fld = 
    ( columnName(fld, entity): fld | <entity, str fld, _> <- s.attrs );
  
  WorkingSet ws = (entity: []);
  
  for (Record record <- rs) {
    //println("RECORD: <record>");
    if (str id := record[typhonId(entity)]) {
      Entity e = <entity, id, ()>;
      
      for (str col <- record, col != typhonId(entity)) {
        e.fields[col2fld[col]] = record[col];
      } 
      
      for (<entity, Cardinality card, str role, str toRole, Cardinality toCard, str to, bool contained> <- s.rels) {
        //println("Recovering relation <entity>.<role> (inverse <to>.<toRole>)");
        if (contained) {
        
          if (<<sql(), db>,  to> <- s.placement) { // it's local
            
            str fkCol = fkName(entity, to, toRole == "" ? role : toRole); 
            SQLStat q = select([ column("x", typhonId(to)) ] 
     						   , [as(tableName(to), "x")]
     						   , [where([equ(column("x", fkCol), lit(text(id)))])]);
     		ResultSet kids = executeQuery(polystoreId, db, pp(q));				
            
            if (card != \one()) { // many-valued
              e.fields[role] = [ uuid(kidId) | Record kid <- kids, str kidId := kid[typhonId(to)] ];
            }
            else { // single valued
              e.fields[role] = [ uuid(kidId) | Record kid <- kids, str kidId := kid[typhonId(to)] ][0];
            }
          }
          else { // it's outside
            SQLStat q = select([ column("x", junctionFkName(to, toRole))]
                                , [as(junctionTableName(entity, role, to, toRole), "x")]
                                , [where([equ(column("x", junctionFkName(entity, role)), lit(text(id)))])]);
            ResultSet kids = executeQuery(polystoreId, db, pp(q));  
            if (card != \one()) {
              e.fields[role] = [ uuid(kidId) | Record kid <- kids, str kidId := kid[junctionFkName(to, toRole)] ];
            }
            else {
              e.fields[role] = [ uuid(kidId) | Record kid <- kids, str kidId := kid[junctionFkName(to, toRole)] ][0];
            }
          }
        
        
        }
        else {  // a cross ref; this subsumes both inside and outside
        
          SQLStat q = select([ column("x", junctionFkName(to, toRole)) ]
                              , [as(junctionTableName(entity, role, to, toRole), "x")]
                              , [where([equ(column("x", junctionFkName(entity, role)), lit(text(id)))])]);
          ResultSet kids = executeQuery(polystoreId, db, pp(q));          
          if (card != \one()) {
            e.fields[role] = [ uuid(kidId) | Record kid <- kids, str kidId := kid[junctionFkName(to, toRole)] ];
          }
          else {
            list[Ref] refs = [ uuid(kidId) | Record kid <- kids, str kidId := kid[junctionFkName(to, toRole)] ]; 
            if (size(refs) > 0) {
              e.fields[role] = refs[0];
            }
            else {
              ; // it was optional (?)
            }
          }
          
        }
      }
      
      ws[entity] += [e];  
    }
    else {
      throw "No id found for <entity> in record <record>";
    }
    
    
  }
  
  return ws;
}

WorkingSet runGetEntities(<mongodb(), str db>, str entity, str polystoreId, Schema s) {  
  list[Doc] docs = find(polystoreId, db, entity, ());
  lrel[str, Doc] flattened = unnest(docs, entity, s);

  //println("flattened: <flattened>");
  WorkingSet result = (entity: []) // this one's always there 
    + ( e : [] | str e <- flattened<0> );
      
  for (<str e, Doc d> <- flattened) {
    result[e] += doc2entity(e, d);
  }
  
  return result;
}
 

Doc dbObject2doc(object(list[Prop] props))
  = ( p.name: dbObject2val(p.val) | Prop p <- props );

Doc dbObject2doc(array(list[DBObject] values))
  = [ dbObject2val(v) | DBObject v <- values ];
 

value dbObject2val(\value(value v)) = v;

value dbObject2val(obj:object(_)) = dbObject2doc(obj);

value dbObject2val(arr:array(_)) = dbObject2doc(arr);
  

// assumes flattening, so no nested docs in d
Entity doc2entity(str entity, Doc d)
  = <entity, id, ( k: toWsValue(d[k]) | str k <- d, k != "_id" )>
  when
    str id := d["_id"];


lrel[str, Doc] unnest(list[Doc] docs, str entity, Schema s) 
  = ( [] | it + unnestRec(d, entity, s) | Doc d <- docs );

lrel[str, Doc] unnestRec(Doc doc, str entity, Schema s) {
  result = [];
  for (<entity, _, str fld, _, _, str to, true> <- s.rels) {
    if (fld in doc, Doc d := doc[fld]) {
      doc[fld] = d["_id"];
      result += unnest(d, to, s);
    }
  }
  result += [<entity, doc>];
  return result;
}






/*
 * Insertion
 */


int runInsert(p:<sql(), str db>, Request ins, str polystoreId, Schema s, Log log = noLog) {
  list[SQLStat] stats = insert2sql(ins, p, s);
  int affected = 0;
  for (SQLStat s <- stats) {
    affected += executeUpdate(polystoreId, db, pp(s));
  }
  return affected;
}

int runInsert(<mongodb(), str db>, Request ins, str polystoreId, Schema s, Log log = noLog) {
  lrel[str, CollMethod] methods = compile2mongo(ins, s);
  for (<str entity, CollMethod method> <- methods) {
    //iprintln(method);
    assert method is \insert;
    for (DBObject obj <- method.documents) {
      insertOne(polystoreId, db, entity, dbObject2doc(obj));
    } 
  }
  return -1;
}

/*
 * Update
 */
 
int runUpdateById(<sql(), str db>, str polystoreId, str entity, str uuid, {KeyVal ","}* kvs) {
  str tbl = tableName(entity);
  SQLStat upd = update(tbl,
      [ \set(columnName("<kv.feature>", entity), lit(evalExpr(kv.\value))) | KeyVal kv <- kvs ],
      [where([equ(column(tbl, typhonId(entity)), lit(text(uuid)))])]);
  return executeUpdate(polystoreId, db, pp(upd)); 
}

int runUpdateById(<mongodb(), str db>, str polystoreId, str entity, str uuid, {KeyVal ","}* kvs) {
  Doc doc = keyvals2update(kvs);
  UpdateResult result = updateOne(polystoreId, db, entity, ("_id": uuid), doc);
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

value eval2value((Expr)`<Real r>`) = toReal("<r>");

value eval2value((Expr)`<DateTime d>`) = readTextValueString(#datetime, "<d>");


default value eval2value(Expr e) {
  throw "Unsupported expression for conversion to value: <e>";
}


/*
 * Deletion
 */  
  

int runDeleteById(<mongodb(), str db>, str polystoreId, str entity, str uuid) {
  deleteOne(polystoreId, db, entity, ("_id": uuid));
  return -1;
}

int runDeleteById(<sql(), str db>, str polystoreId, str entity, str uuid) {
  str tbl = tableName("<entity>");
  SQLStat stat = delete(tbl, [where([equ(column(tbl, typhonId(entity)), lit(text(uuid)))])]);
  return executeUpdate(polystoreId, db, pp(stat));
}


/*

WorkingSet runQuery(<sql(), str db>, (Request)`<Query q>`, Schema s, Log log = noLog) {
  log("[RUN-query/sql/<db>] <q>");
  SQLStat stat = select2sql(q, s);
  
  log("[RUN-query/sql/<db>] <pp(stat)>");
  
  ResultSet rs = executeQuery(db, pp(stat));
  
  log("[RUN-query/sql/<db>] resultset = <rs>");
  
  WorkingSet ws = ();

  tuple[str,str] splitColName(str col) = <l, r>
    when [str l, str r] := split(".", col);
  
  for (Record r <- rs) {
    rel[str,str,value] values = { <e, f, r[col]> | str col <- r, <str e, str f> := splitColName(col) };
    
    println("values = <values>");
    
    for (str e <- values<0>) {
      if (e notin ws) {
        ws[e] = [];
      }
      ws[e] += [ <e, id, (f: toWsValue(v) | <str f, value v> <- values[e], f != typhonId(e) )> | str id := r[typhonId(e)] ];
    }
  }
  iprintln(ws);
  return ws;
}

WorkingSet runQuery(<mongodb(), str db>, Request q, Schema s, Log log = noLog) {
  lrel[str, CollMethod] methods = compile2mongo(q, s);
  
  // NB: this is unwrapping the "legacy" mongo compiler, dbObject and CollMethod need to go.
  
  WorkingSet result = ();
  
  for (<str entity, CollMethod method> <- methods) {
    assert method is find;
    
    list[Doc] docs = find(db, entity, dbObject2doc(method.query));
    
    iprintln(docs);
    
    //lrel[str, Doc] flattened = unnest(docs);
    
    flattened = unnest(docs, entity, s);
    
    println("FLATTENED: <flattened>");
    
    
    for (<str e, Doc d> <- flattened) {
      if (e notin result) {
        result[e] = [];
      }
      result[e] += doc2entity(e, d);
    }
  }
  
  return result;
}
*/