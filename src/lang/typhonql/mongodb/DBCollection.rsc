module lang::typhonql::mongodb::DBCollection

import IO;
import List;


alias Prop
  = tuple[str name, DBObject val];  
  
data DBObject  
  = object(list[Prop] props)
  | array(list[DBObject] values)
  | \value(value v)
  | placeholder() // simulating a kind of ? for doing updates and deletes
  ;
    
// I'm skipping all readpreference, DBEncode, Object and *Options things  

// NB: the names, arities and types of the match the methods names and params in Java exactly,
// so we can use reflection to map a CollMethod to an actual method call on DBCollection.
// where ...varargs become keyword params, List<...> list, and array[] also list
  
data CollMethod
  = aggregate(DBObject firstOp, list[DBObject] additionalOps = [])
  | aggregate(list[DBObject] pipeline)	
  | count()	
  | count(DBObject query)	
  | createIndex(DBObject keys)	
  | createIndex(DBObject keys, DBObject options)	
  | createIndex(DBObject keys, str name)	
  | createIndex(DBObject keys, str name, bool unique)	
  | createIndex(str name)	
  | distinct(str fieldName)	
  | distinct(str fieldName, DBObject query)	
  | drop()	
  | dropIndex(DBObject index)	
  | dropIndex(str indexName)	
  | dropIndexes()	
  | dropIndexes(str indexName)	
  | find()	
  | find(DBObject query)	
  | find(DBObject query, DBObject projection)	
  | find(DBObject query, DBObject projection, int numToSkip, int batchSize)	
  | findAndModify(DBObject query, DBObject update)	
  | findAndModify(DBObject query, DBObject sort, DBObject update)	
  | findAndModify(DBObject query, DBObject fields, DBObject sort, bool remove, DBObject update, bool returnNew, bool upsert)	
  | findAndModify(DBObject query, DBObject fields, DBObject sort, bool remove, DBObject update, bool returnNew, bool upsert, bool bypassDocumentValidation, int maxTime, TimeUnit maxTimeUnit)	
  | findAndModify(DBObject query, DBObject fields, DBObject sort, bool remove, DBObject update, bool returnNew, bool upsert, bool bypassDocumentValidation, int maxTime, TimeUnit maxTimeUnit, WriteConcern writeConcern)	
  | findAndModify(DBObject query, DBObject fields, DBObject sort, bool remove, DBObject update, bool returnNew, bool upsert, int maxTime, TimeUnit maxTimeUnit)	
  | findAndModify(DBObject query, DBObject fields, DBObject sort, bool remove, DBObject update, bool returnNew, bool upsert, int maxTime, TimeUnit maxTimeUnit, WriteConcern writeConcern)	
  | findAndModify(DBObject query, DBObject fields, DBObject sort, bool remove, DBObject update, bool returnNew, bool upsert, WriteConcern writeConcern)	
  | findAndRemove(DBObject query)	
  | findOne()	
  | findOne(DBObject query)	
  | findOne(DBObject query, DBObject projection)	
  | findOne(DBObject query, DBObject projection, DBObject sort)	
  | getCollection(str name)	
  | getCount()	
  | getCount(DBObject query)	
  | getCount(DBObject query, DBObject projection)	
  | getCount(DBObject query, DBObject projection, int limit, int skip)	
  | group(DBObject key, DBObject cond, DBObject initial, str reduce)	
  | group(DBObject key, DBObject cond, DBObject initial, str reduce, str finalize)	
  | \insert(list[DBObject] documents)	
  | \insert(list[DBObject] documents, WriteConcern writeConcern)	
  | \insert(DBObject document, WriteConcern writeConcern)	
  | \insert(WriteConcern writeConcern, list[DBObject] documents = [])	
  | \insert(list[DBObject] documents)	
  | remove(DBObject query)	
  | remove(DBObject query, WriteConcern writeConcern)	
  | rename(str newName)	
  | rename(str newName, bool dropTarget)	
  | save(DBObject document)	
  | save(DBObject document, WriteConcern writeConcern)	
  | update(DBObject query, DBObject update)	
  | update(DBObject query, DBObject update, bool upsert, bool multi)	
  | update(DBObject query, DBObject update, bool upsert, bool multi, WriteConcern aWriteConcern)	
  | updateMulti(DBObject query, DBObject update)
  ;

data WriteConcern
  = ACKNOWLEDGED()
  | JOURNALED()
  | MAJORITY()
  | W1()
  | W2()
  | W3();

data ReadConcern
  = DEFAULT()
  | LINEARIZABLE()
  | LOCAL()
  | MAJORITY()
  | SNAPSHOT()
  ;

data TimeUnit
  = DAYS() | HOURS() | MICROSECONDS() | MILLISECONDS() | MINUTES() | NANOSECONDS() | SECONDS();	
  