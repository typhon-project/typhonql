module lang::typhonql::Script

import lang::typhonml::Util;
import lang::typhonql::Session;

import IO;

data Script
  = script(list[Step] steps);

data Step
  // meaning of a step: x = call(params)
  // TyphonQL: from Person p select p.name
  // SQL: select p.name as x1 from Person  p
  // executeQuery("x", "relational", "select p.name from Person as p", ())
  = step(str result, Call call, Bindings bindings, list[Path] signature = [])
  | read(list[Path] path)
  | newId(str var)
  ;
  

data Call
  = sql(SQLCall jdbc)
  | mongo(MongoCall mongo) 
  ;
data SQLCall
  = executeQuery(str dbName, str query)
  | executeStatement(str dbName, str stat)
  | executeGlobalStatement(str dbName, str stat)
  ;
  
data MongoCall
  = find(str dbName, str coll, str query)
  | find(str dbName, str coll, str query, str proj)
  | insertOne(str dbName, str coll, str doc)
  | findAndUpdateOne(str dbName, str coll, str query, str update)
  | findAndUpdateMany(str dbName, str coll, str query, str update)
  | deleteOne(str dbName, str coll, str query)
  | deleteMany(str dbName, str coll, str query)
  | createCollection(str dbName, str coll)
  | dropCollection(str dbName, str coll)
  | dropDatabase(str dbName)
  ;
  
EntityModels schema2entityModels(Schema s) 
  = { <e, { <a, t> | <e, str a, str t> <- s.attrs }
          , { <r, e2> | <e, _, str r, _, _, str e2, _> <- s.rels } >
           | str e <- entities(s) };
  

  
  
str runScript(Script scr, Session session, Schema schema) {
  str result = "";
  for (Step s <- scr.steps) {
    switch (s) {
      case step(str r, sql(executeQuery(str db, str q)), Bindings ps):
        session.sql.executeQuery(r, db, q, ps, s.signature);
        
      case step(str r, sql(executeStatement(str db, str st)), Bindings ps):
        session.sql.executeStatement(db, st, ps);
      
      case step(str r, sql(executeGlobalStatement(str db, str st)), Bindings ps):
        session.sql.executeGlobalStatement(db, st, ps);  

      case step(str r, mongo(find(str db, str coll, str json)), Bindings ps):
        session.mongo.find(r, db, coll, json, ps, s.signature);
        
      case step(str r, mongo(find(str db, str coll, str json, str proj)), Bindings ps):
        session.mongo.findWithProjection(r, db, coll, json, proj, ps, s.signature);  
        
      case step(str r, mongo(insertOne(str db, str coll, str doc)), Bindings ps):
        session.mongo.insertOne(db, coll, doc, ps); 
        
      case step(str r, mongo(findAndUpdateOne(str db, str coll, str query, str update)), Bindings ps):
        session.mongo.findAndUpdateOne(db, coll, query, update, ps);   
        
      case step(str r, mongo(deleteOne(str db, str coll, str query)), Bindings ps):
        session.mongo.deleteOne(db, coll, query, ps); 
      
      case step(str r, mongo(deleteMany(str db, str coll, str query)), Bindings ps):
        println("WARNING: not yet executed: <s>"); 
        
      case step(str r, mongo(createCollection(str db, str coll)), Bindings ps):
        session.mongo.createCollection(db, coll); 
        
      case step(str r, mongo(dropCollection(str db, str coll)), Bindings ps):
        session.mongo.dropCollection(db, coll); 
        
      case step(str r, mongo(dropDatabase(str db)), Bindings ps):
        session.mongo.dropDatabase(db);   
       
      case newId(str var): {
        result = session.newId(var);
      }
          
      case read(list[Path path] paths): {
      	session.readAndStore(paths);
      }
  	  	
      default: throw "Unsupported call: <s>";
    }
  }
  
  //str (str result, rel[str name, str \type] entities, EntityModels models) read,
 	//alias EntityModels = rel[str name, rel[str name, str \type] attributes, rel[str name, str entity] relations];
  //EntityModels models = schema2entityModels(schema);
      
           
  //str result = session.read(scr.steps[-1].result, {<"product", "Product">}, models);
 	//
  //println(result);
  return result;
}