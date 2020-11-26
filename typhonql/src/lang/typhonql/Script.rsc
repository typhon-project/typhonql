/********************************************************************************
* Copyright (c) 2018-2020 CWI & Swat.engineering 
*
* This program and the accompanying materials are made available under the
* terms of the Eclipse Public License 2.0 which is available at
* http://www.eclipse.org/legal/epl-2.0.
*
* This Source Code may also be made available under the following Secondary
* Licenses when the conditions for such availability set forth in the Eclipse
* Public License, v. 2.0 are satisfied: GNU General Public License, version 2
* with the GNU Classpath Exception which is
* available at https://www.gnu.org/software/classpath/license.html.
*
* SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0
********************************************************************************/

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
  | javaRead(str className, str javaContents, list[Path] path, list[str] finalColumnNames)
  | finish()
  | newId(str var)
  ;
  

data Call
  = sql(SQLCall jdbc)
  | mongo(MongoCall mongo) 
  | cassandra(CassandraCall cassandra)
  | neo(NeoCall neo)
  | nlp(NlpCall nlp)
  ;
  
data CassandraCall
  = cExecuteQuery(str dbName, str cql)
  | cExecuteStatement(str dbName, str cql)
  | cExecuteGlobalStatement(str dbName, str cql)
  ;  
  
data SQLCall
  = executeQuery(str dbName, str query)
  | executeStatement(str dbName, str stat)
  | executeGlobalStatement(str dbName, str stat)
  ;
  
data NeoCall
  = executeNeoQuery(str dbName, str query)
  | executeNeoUpdate(str dbName, str stat)
  ;
  
data NlpCall
  = process(str json)
  | delete(str json)
  | query(str json)
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
  | createIndex(str dbName, str coll, str indexName, str keys)
  | dropIndex(str dbName, str coll, str indexName)
  | renameCollection(str dbName, str coll, str newName)
  | dropCollection(str dbName, str coll)
  | dropDatabase(str dbName)
  ;
  
EntityModels schema2entityModels(Schema s) 
  = { <e, { <a, t> | <e, str a, str t> <- s.attrs }
          , { <r, e2> | <e, _, str r, _, _, str e2, _> <- s.rels } >
           | str e <- entities(s) };
           
list[str] runScript(Script scr, Session session, Schema schema) {
	if (!session.hasAnyExternalArguments()) {
		return [runScriptAux(scr, session, schema)];
	}
	else {
		rs = [];
		while (session.hasMoreExternalArguments()) {
			rs += runScriptAux(scr, session, schema);
			session.nextExternalArguments();
		}
		return rs;
	}
}  
         

str runScriptAux(Script scr, Session session, Schema schema) {
  str result = "";
  for (Step s <- scr.steps) {
    switch (s) {
      case step(str r, cassandra(cExecuteQuery(str db, str q)), Bindings ps):
        session.cassandra.executeQuery(r, db, q, ps, s.signature);

      case step(str r, cassandra(cExecuteStatement(str db, str q)), Bindings ps):
        session.cassandra.executeStatement(db, q, ps);

      case step(str r, cassandra(cExecuteGlobalStatement(str db, str q)), Bindings ps):
        session.cassandra.executeGlobalStatement(db, q, ps);
    
    
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
        session.mongo.deleteMany(db, coll, query, ps); 
        
      case step(str r, mongo(createCollection(str db, str coll)), Bindings ps):
        session.mongo.createCollection(db, coll); 

      case step(str r, mongo(createIndex(str db, str coll, str indexName, str keys)), Bindings ps):
        session.mongo.createIndex(db, coll, indexName, keys); 

      //case step(str r, mongo(createIndex(str db, str coll, lrel[str selector, str index] selectors)), Bindings ps):
      //  session.mongo.createIndex(db, coll, selectors); 
        
      case step(str r, mongo(dropCollection(str db, str coll)), Bindings ps):
        session.mongo.dropCollection(db, coll); 
        
      case step(str r, mongo(dropIndex(str db, str coll, str indexName)), Bindings ps):
        session.mongo.dropIndex(db, coll, indexName); 
        
      case step(str r, mongo(dropDatabase(str db)), Bindings ps):
        session.mongo.dropDatabase(db);   
       
      case step(str r, mongo(findAndUpdateMany(str db, str coll, str query, str update)), Bindings ps):
        session.mongo.findAndUpdateMany(db, coll, query, update, ps);
        
      case step(str r, neo(executeNeoQuery(str db, str q)), Bindings ps):
        session.neo.executeMatch(r, db, q, ps, s.signature);
        
      case step(str r, neo(executeNeoUpdate(str db, str q)), Bindings ps):
        session.neo.executeUpdate(db, q, ps);
        
      case step(str r, nlp(process(str json)), Bindings ps):
      	session.nlp.process(json, ps);
      	
      case step(str r, nlp(delete(str json)), Bindings ps):
      	session.nlp.delete(json, ps);
      
      case step(str r, nlp(query(str json)), Bindings ps):
      	session.nlp.query(json, ps, s.signature);	
      
      case newId(str var): {
        result = session.newId(var);
      }
      
      case javaRead(str className, str javaContents, list[Path] path, list[str] finalColumnNames): {
        session.javaReadAndStore(className, javaContents, path, finalColumnNames);
      }
          
      case read(list[Path path] paths): {
      	session.readAndStore(paths);
      }

      case finish(): {
        session.finish();
      }

  	  	
      default: throw "Unsupported call: <s>";
    }
  }
  
  return result;
}
