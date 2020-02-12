module lang::typhonql::Script

import lang::typhonml::Util;
import lang::typhonql::Session;

data Script
  = script(list[Step] steps);

data Step
  // meaning of a step: x = call(params)
  // TyphonQL: from Person p select p.name
  // SQL: select p.name as x1 from Person  p
  // executeQuery("x", "relational", "select p.name from Person as p", ())
  = step(str result, Call call, Bindings bindings);

data Call
  = sql(SQLCall jdbc)
  | mongo(MongoCall mongo) 
  ;
data SQLCall
  = executeQuery(str dbName, str query)
  | executeStatement(str dbName, str stat)
  ;
  
data MongoCall
  = find(str dbName, str coll, str json)
  ;
  
EntityModels schema2entityModels(Schema s) 
  = { <e, { <a, t> | <e, str a, str t> <- s.attrs }
          , { <r, e2> | <e, _, str r, _, _, str e2, _> <- s.rels } >
           | str e <- entities(s) };
  
void runScript(Script scr, Session session, Schema schema) {
  for (Step s <- scr.steps) {
    switch (s) {
      case step(str r, sql(executeQuery(str db, str q)), Bindings ps):
        session.sql.executeQuery(r, db, q, ps);

      case step(str r, mongo(find(str db, str coll, str json)), Bindings ps):
        session.mongo.find(r, db, coll, json, ps);
        
      default: throw "Unsupported call: <s.call>";
    }
  }
  
  //str (str result, rel[str name, str \type] entities, EntityModels models) read,
 	//alias EntityModels = rel[str name, rel[str name, str \type] attributes, rel[str name, str entity] relations];
  //EntityModels models = schema2entityModels(schema);
      
           
  //str result = session.read(scr.steps[-1].result, {<"product", "Product">}, models);
 	//
  //println(result);
}