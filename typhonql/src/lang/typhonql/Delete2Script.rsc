module lang::typhonql::Delete2Script


import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::Script;
import lang::typhonql::Session;
import lang::typhonql::TDBC;
import lang::typhonql::Order;
import lang::typhonql::Normalize;

import lang::typhonql::Insert2Script;
//import lang::typhonql::Update2Script;
import lang::typhonql::References;
import lang::typhonql::Query2Script;



import lang::typhonql::relational::SQL;
import lang::typhonql::relational::Util;
import lang::typhonql::relational::SQL2Text;
import lang::typhonql::relational::Query2SQL;

import lang::typhonql::mongodb::Query2Mongo;
import lang::typhonql::mongodb::DBCollection;

import IO;
import List;

Script delete2script((Request)`delete <EId e> <VId x> where <{Expr ","}+ ws>`, Schema s) {
  //s.rels = symmetricReduction(s.rels);
  
  str ent = "<e>";
  Place p = placeOf(ent, s);

  Param toBeDeleted = field(p.name, "<x>", ent, "@id");
  str myId = newParam();
  SQLExpr sqlMe = lit(Value::placeholder(name=myId));
  DBObject mongoMe = DBObject::placeholder(name=myId);
  Bindings myParams = ( myId: toBeDeleted );
  Script scr = script([]);
  
  if ((Where)`where <VId _>.@id == <UUID mySelf>` := (Where)`where <{Expr ","}+ ws>`) {
    sqlMe = lit(evalExpr((Expr)`<UUID mySelf>`));
    mongoMe = \value("<mySelf>"[1..]);
    myParams = ();
  }
  else {
    // first, find all id's of e things that need to be updated
    Request req = (Request)`from <EId e> <VId x> select <VId x>.@id where <{Expr ","}+ ws>`;
    // NB: no partitioning, compile locally.
    scr.steps = compileQuery(req, p, s);
  }
  
   
  switch (p) {
    case <sql(), str dbName>: {
      

      str from = "<e>";

      // delete kids that are not on dbName
      for (<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels) {
            // this keyval is updating ref to have me as a parent/owner
          // local deletions go via cascade delete
          
          switch (placeOf(to, s)) {
          
            case <sql(), dbName> : {
              ;  
            }
            
            case <sql(), str other> : {
              // cascadeViaJunction deletes from "to" and from the (inverse) junction table modeling
              // this containment relation
              scr.steps += cascadeViaJunction(other, to, toRole, from, fromRole, sqlMe, myParams);
            }
            
            case <mongodb(), str other>: {
              // delete all to's in mongo that toRole to be mongoMe
              scr.steps += cascadeViaInverse(other, to, toRole, mongoMe, myParams); 
            }
            
          }
        }
        
        // break links with parent (if any)
       for (<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true> <- s.rels) {
          // this is the case where "me" is owned by something, we don't want to delete
          // the parents here, but need (non-local) links in junction tables and update inverses.
           
          switch (placeOf(parent, s)) {
          
            case <sql(), dbName> : {  
              // nothing: the junction table entry will be deleted via cascade delete.
              ;
            }
            
            case <sql(), str other> : {
              scr.steps += removeFromJunction(dbName, parent, parentRole, from, fromRole, sqlMe, myParams);
              scr.steps += removeFromJunction(other, parent, parentRole, from, fromRole, sqlMe, myParams);
            }
            
            case <mongodb(), str other>: {
              scr.steps += removeFromJunction(dbName, parent, parentRole, from, fromRole, sqlMe, myParams);
              scr.steps += removeAllObjectPointers(other, parent, parentRole, mongoMe, myParams);
            }
            
          }
        }
        
      // break cross references  
      for (<from, _, fromRole, str toRole, Cardinality toCard, str to, false> <- trueCrossRefs(s.rels)) {
           
           switch (placeOf(to, s)) {
             case <sql(), dbName>: {
               ; // nothing to be done, locally, the same junction table is used
               // for both directions.
             }
             case <sql(), str other>: {
               scr.steps += removeFromJunction(other, to, toRole, from, fromRole, sqlMe, myParams);
             }
             case <mongodb(), str other>: {
               scr.steps += removeAllObjectPointers(other, to, toRole, toCard, mongoMe, myParams);
             }
           }
        
        }

      // delete the thing itself
      SQLStat stat = delete(tableName(ent),
          [where([equ(column(tableName(ent), typhonId(ent)), sqlMe)])]);
          
      scr.steps += [step(dbName, sql(executeStatement(dbName, pp(stat))), myParams) ]; 
    }
    
    case <mongodb(), str dbName>: {
      str from = "<e>";

      // delete kids that are not on dbName
      for (<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels) {
          
          switch (placeOf(to, s)) {
          
            case <mongodb(), dbName> : {
              ;  // immediate
            }
            
            case <mongodb(), str other> : {
              // delete all to's in mongo that toRole to be mongoMe
              scr.steps += cascadeViaInverse(other, to, toRole, mongoMe, myParams);
            }
            
            case <sql(), str other>: {
			  // cascadeViaJunction deletes from "to" and from the (inverse) junction table modeling
              // this containment relation
              scr.steps += cascadeViaJunction(other, to, toRole, from, fromRole, sqlMe, myParams);               
            }
            
          }
        }
        
        // break links with parent (if any)
       for (<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true> <- s.rels) {
          // this is the case where "me" is owned by something, we don't want to delete
          // the parents here, but need (non-local) links in junction tables and update inverses.
           
          switch (placeOf(parent, s)) {
          
            case <mongodb(), dbName> : {  
              // ???? nesting strikes again.
              ;
            }
            
            case <mongo(), str other> : {
              scr.steps += removeAllObjectPointers(other, parent, parentRole, from, fromRole, mongoMe, myParams);
            }
            
            case <sql(), str other>: {
               scr.steps += removeFromJunction(other, from, fromRole, parent, parentRole, sqlMe, myParams);
            }
            
          }
        }
        
      // break cross references  
      for (<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false> <- trueCrossRefs(s.rels)) {
           
           switch (placeOf(to, s)) {
             case <mongodb(), dbName>: {
               scr.steps += removeAllObjectPointers(other, to, toRole, mongoMe, myParams);
             }
             case <mongodb(), str other>: {
               scr.steps += removeAllObjectPointers(other, to, toRole, mongoMe, myParams);
             }
             case <sql(), str other>: {
               scr.steps += removeFromJunction(other, to, toRole, from, fromRole, sqlMe, myParams);
             }
           }
        
      }
      
      scr.steps += [ step(dbName, mongo(
        deleteOne(dbName, ent, pp(object([<"_id", mongoMe>])))), myParams) ];
      
    }
    
  }
  
  scr.steps += [finish()];
  
  return scr;
}