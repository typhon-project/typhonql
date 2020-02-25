module lang::typhonql::Insert2Script

import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::Script;
import lang::typhonql::Session;
import lang::typhonql::TDBC;
import lang::typhonql::Order;
import lang::typhonql::Normalize;

import lang::typhonql::relational::SQL;
import lang::typhonql::relational::Util;
import lang::typhonql::relational::SQL2Text;
import lang::typhonql::relational::Query2SQL;
import lang::typhonql::relational::Insert2SQL;

import lang::typhonql::mongodb::Query2Mongo;
import lang::typhonql::mongodb::Insert2Mongo;
import lang::typhonql::mongodb::DBCollection;

import IO;
import List;

bool hasId({KeyVal ","}* kvs) = any((KeyVal)`@id: <Expr _>` <- kvs);

str evalId({KeyVal ","}* kvs) = "<e>"[1..]
  when (KeyVal)`@id: <UUID e>` <- kvs;


list[Step] insertIntoJunction(str dbName, str from, str fromRole, str to, str toRole, SQLExpr src, SQLExpr trg, Bindings params) {
  return [step(dbName, sql(dbName, \insert(junctionTableName(from, fromRole, to, toRole)
       , [junctionFkName(from, fromRole), junctionFkName(to, toRole)]
                        , [src, trg])), params)];
}

list[Step] updateObjectPointer(str dbName, str coll, DBObject subject, str role, Cardinality card, DBObject target, Bindings params) {
    return [
      step(dbName, mongo(dbName, coll, findAndUpdateOne(coll,
          // todo: multiplicity 
          object([<"_id", subject>]), object([<"$set", object([<role, target>])>]))))
          ];
}

Script insert2script((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, Schema s) {
  Place p = placeOf("<e>", s);
  str myId = newParam();
  Bindings myParams = ( myId: generatedId(myId) );
  SQLExpr sqlMe = hasId(kvs) ? lit(text(evalId(kvs))) : SQLExpr::placeholder(name=myId);
  DBObject mongoMe = hasId(kvs) ? \value(evalId(kvs)) : DBObject::placeholder(name=myId);
  
  list[Step] steps = [];    
      
  switch (p) {
    case <sql(), str dbName>: {
      
      list[str] aCols({KeyVal ","}* kvs, str entity) 
	    = [ *columnName(kv, entity) | KeyVal kv  <- kvs, isAttr(kv, entity, s)]
	    + [ typhonId(entity) ];
  
	  list[SQLExpr] aVals({KeyVal ","}* kvs, str entity) 
	    = [ *evalKeyVal(kv) | KeyVal kv <- kvs, isAttr(kv, entity, s) ]
	    + [ sqlMe ];
      
      SQLStat theInsert = \insert(tableName("<e>"), aCols(kvs, "<e>"), aVals(kvs, "<e>")) ; 
      
      for ((KeyVal)`<Id x>: <UUID ref>` <- kvs) {
        str from = "<e>";
        str fromRole = "<x>";
        str uuid = "<ref>"[1..];
        if (<from, _, fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels) {
            // this keyval is updating ref to have me as a foreign key
            
          switch (placeof(to, s)) {
          
            case <sql(), dbName> : {  
              // update ref's foreign key to point to sqlMe
              str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
              SQLState theUpdate = update(tableName(to), [\set(fk, sqlMe)],
                [where([equ(column(tableName(to), typhonId(to)), lit(text(uuid)))])]);
                
              steps += [step(dbName, sql(executeUpdate(dbName, pp(theUpdate))), myParams)];
            }
            
            case <sql(), str other> : {
               // insert entry in junction table between from and to on the current place.
              steps += insertIntoJunction(p.name, from, fromRole, to, toRole, sqlMe, lit(text(uuid)), myParams);
              steps += insertIntoJunction(other, to, toRole, from, fromRole, lit(text(uuid)), sqlMe, myParams);
            }
            
            case <mongodb(), str other>: {
              // insert entry in junction table between from and to on the current place.
              steps += insertIntoJunction(p.name, from, fromRole, to, toRole, sqlMe, lit(text(uuid)), myParams);
              steps += updateObjectPointer(other, to, toRole, toCard, \value(uuid), mongoMe, myParams);
              
            }
            
          }
        }
        else if (<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true> <- s.rels) {
           // this is the case that the current KeyVal pair is actually
           // setting the currently inserted object as being owned by ref
           
           switch (placeOf(parent, s)) {
             case <sql(), dbName>: {
               // set foreign key of sqlMe to point to uuid
                str fk = fkName(parent, from, fromRole == "" ? parentRole : fromRole);
                theInsert.colNames += [ fk ];
                theInsert.values += [ lit(text(uuid)) ];
                steps += step(dbName, sql(executeStatement(dbName, pp(theInsert))), myParams);
             }
             case <sql(), str other>: {
                steps += insertIntoJunction(p.name, from, fromRole, parent, parentRole, lit(text(uuid)), sqlMe, myParams);
                steps += insertIntoJunction(other, parent, parentRole, from, fromRole, lit(text(uuid)), sqlMe, myParams);
             }
             case <mongodb(), str other>: {
               steps += insertIntoJunction(p.name, from, fromRole, parent, parentRole, lit(text(uuid)), sqlMe, myParams);
               steps += updateObjectPointer(other, parent, parentRole, parentCard, \value(uuid), mongoMe, myParams);
             }
           }
        } 
        else if (<from, _, fromRole, str toRole, _, str to, false> <- s.rels) {
           if (placeOf(to, s) == p) {
             ;
           }
           else {
             ;
           
           }
        
        }
        
        
         
      }
      
      for ((KeyVal)`<Id x>: [<{UUID ","}+ refs>]` <- kvs, UUID ref <- refs) {
        throw "Lists not supported in insert (yet)";
      }
    }

    case <mongodb(), str dbName>: {
      return script([newId(myId)] + insert2mongo(r, s, p, myId, myParam));
    }
  }
}