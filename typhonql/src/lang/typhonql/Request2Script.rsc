module lang::typhonql::Request2Script


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

/*

TODO:

- modularize using pattern-based dispatch
- use toRole matching to "" to determine the canonical relation in case of non-ownership
- clean-up the PARAM string passing
- custom data type expansion
- NLP hooks

*/


Script request2script(Request r, Schema s) {
  switch (r) {
  
    case (Request)`<Query q>`: {
      list[Place] order = orderPlaces(r, s);
      return script([ *compileQuery(restrict(r, p, order, s), p, s) | Place p <- order]); 
    }

    case (Request)`update <EId e> <VId x> set {<{KeyVal ","}* kvs>}`: {
      return request2script((Request)`update <EId e> <VId x> where true set {<{KeyVal ","}* kvs>}`, s);
    }
    
    case (Request)`update <EId e> <VId x> where <{Expr ","}+ ws> set {<{KeyVal ","}* kvs>}`: {

      str ent = "<e>";
      Place p = placeOf(ent, s);

       // first, find all id's of e things that need to be updated
      Request req = (Request)`from <EId e> <VId x> select <VId x>.@id where <{Expr ","}+ ws>`;
      
      // NB: no partitioning, compile locally.
      Script scr = script(compileQuery(req, p, s));
      
      Param toBeUpdated = field(p.name, "<x>", ent, "@id");
       
      // update the primitivies
      switch (p) {
        case <sql(), str dbName>: {
          SQLStat stat = update(tableName(ent),
            [ Set::\set(columnName("<kv.key>", ent), SQLExpr::lit(evalExpr(kv.\value))) | KeyVal kv <- kvs, isAttr(kv, ent, s) ],
              [where([equ(column(tableName(ent), typhonId(ent)), SQLExpr::placeholder(name="TO_UPDATE"))])]);
          if (stat.sets != []) {
            scr.steps += [step(dbName, sql(executeStatement(dbName, pp(stat))), ("TO_UPDATE": toBeUpdated))];
          }
        }
        
        case <mongodb(), str dbName>: {
          DBObject q = object([<"_id", DBObject::placeholder(name="TO_UPDATE")>]);
          // NB: keyVal2Prop allows @id fields, but they should *never be set in update -> type checker
          DBObject u = object([ keyVal2prop(kv) | KeyVal kv <- kvs, isAttr(kv, ent, s) ]);
          if (u.props != []) {
            scr.steps += [step(dbName, mongo(findAndUpdateOne(dbName, ent, pp(q), pp(u))), ("TO_UPDATE": toBeUpdated))];
          }
        }
      
      }
      
      /*
       * what to do about nested objects? for now, we don't support them.
      */


      for ((KeyVal)`<Id fld>: <UUID ref>` <- kvs) {
        scr.steps += updateReference(p, ent, fld, ref, "TO_UPDATE", toBeUpdated, s);
      }

      for ((KeyVal)`<Id fld>: [<{UUID ","}+ refs>]` <- kvs) {
        scr.steps += updateManyReference(p, ent, fld, refs, "TO_UPDATE", toBeUpdated, s);
      }

      
      for ((KeyVal)`<Id fld> +: [<{UUID ","}+ refs>]` <- kvs) {
        scr.steps += addToManyReference(p, ent, fld, refs, "TO_UPDATE", toBeUpdated, s);
      }
      
      for ((KeyVal)`<Id fld> -: [<{UUID ","}+ refs>]` <- kvs) {
        scr.steps += removeFromManyReference(p, ent, fld, refs, "TO_UPDATE", toBeUpdated, s);
      }
      
      return scr;
    }
    
    case (Request)`delete <EId e> <VId x>`: {
      return request2script((Request)`delete <EId e> <VId x> where true`, s);
    }
    
    case (Request)`delete <EId e> <VId x> where <{Expr ","}+ ws>`: {
      str ent = "<e>";
      Place p = placeOf(ent, s);
      
      // first, find all id's of e things that need to be deleted
      // including the kid id's of all non-locally owned entities
      // NB: since we're only deleted a single entity type, partitioning has no effect
      // on this query, and we get a single "param" corresponding to p.name
      list[str] results = ["<x>.@id"]
        + [ "<x>.<f>" | <ent, _, str f, _, _, str to, true> <- s.rels, placeOf(to, s) != p ];

      Request req = [Request]"from <e> <x> select <intercalate(", ", results)> where <ws>";

      Script scr = script(compileQuery(req, p, s));
      
      Param toBeDeleted = field(p.name, "<x>", "<e>", "@id");
     
     
      scr.steps += breakLinksWithParent(ent, toBeDeleted, p, s);
      scr.steps += cascadeToKids(ent, toBeDeleted, x, p, s);
      
      // then delete the entity itself
      
      switch (p) {
        case <sql(), str dbName>: {
          SQLStat stat = delete(tableName(ent), [
            where([
             equ(column(tableName(ent), typhonId(ent)), SQLExpr::placeholder(name="TO_DELETE"))
            ])]);
            
          scr.steps += [step(dbName, sql(executeStatement(dbName, pp(stat))), ("TO_DELETE": toBeDeleted))];  
        }
        
        case <mongodb(), str dbName>: {
          DBObject q = object([<"_id", DBObject::placeholder(name="TO_DELETE")>]);
          scr.steps += [step(dbName, mongo(deleteOne(dbName, ent, pp(q))),  ("TO_DELETE": toBeDeleted))];
        }
      }
      
      return scr;
      
    }

    case (Request)`insert <EId e> { <{KeyVal ","}* kvs> }`: {
      Place p = placeOf("<e>", s);
      str myId = newParam();
      Param myParam = generatedId(myId);
      switch (p) {
        case <sql(), str dbName>: {
          return script([newId(myId)] + insert2sql(r, s, p, myId, myParam));
        }

        case <mongodb(), str dbName>: {
          return script([newId(myId)] + insert2mongo(r, s, p, myId, myParam));
        }
      }
    }
  
    case (Request)`insert <EId e> { <{KeyVal ","}* kvs> } into <UUID owner>.<Id field>`: {
      Place p = placeOf("<e>", s);
      if (<str parent, _, str fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels, fromRole == "<field>", to == "<e>") {
        Place parentPlace = placeOf(parent, s);
        str uuid = "<owner>"[1..];
        str kidParam = newParam();
        Param kidValue = generatedId(kidParam);
        switch (<parentPlace, p>) {
            case <<sql(), str dbName>, <sql(), dbName>>: {
               str fk = fkName(parent, to, toRole == "" ? fromRole : toRole);
 			   return script([newId(kidParam)] 
 			     + insert2sql((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, s, p, kidParam, kidValue, parent = <fk, "<owner>">));
            }

            case <<sql(), str dbParent>, <sql(), str dbKid>>: {
              return script([newId(kidParam)]
                + createCrossLinkInSQL(dbParent, parent, uuid, kidParam, kidValue, fromRole, to, toRole)
                + insert2sql((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, s, p, kidParam, kidValue));
			}

            case <<sql(), str dbParent>, <mongodb(), str dbKid>>: {
              return script([newId(kidParam)]  
                + createCrossLinkInSQL(dbParent, parent, uuid, kidParam, kidValue, fromRole, to, toRole)
                + insert2mongo((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, s, p, kidParam, kidValue));          
			  
			}
            
            case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
              return script([newId(kidParam)]  
                 + createCrossLinkInMongo(dbName, parent, uuid, kidParam, kidValue, fromRole, toCard)
                 + insert2mongo((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, s, p, kidParam, kidValue));
            }
            
            case <<mongodb(), str dbParent>, <mongodb(), str dbKid>>: {
              return script([newId(kidParam)]
                + createCrossLinkInMongo(dbParent, parent, uuid, kidParam, kidValue, fromRole, toCard) 
                + insert2mongo((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, s, p, kidParam, kidValue));
            }

            case <<mongodb(), str dbParent>, <sql(), str dbKid>>: {
              return script([newId(kidParam)]
                + createCrossLinkInMongo(dbParent, parent, uuid, kidParam, kidValue, fromRole, toCard) 
                + insert2sql((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, s, p, kidParam, kidValue));
            }
        }
      }
      else {
        throw "No owner type found for entity <e> via <field>";
      }
    }
    
    default: 
      throw "Unsupported request: `<r>`";
  }    
}

list[Step] cascadeToKids(str ent, Param toBeDeleted, VId x, Place p, Schema s) {
  list[Step] steps = [];
  for (<ent, _, str fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels, placeOf(to, s) != p) {
    Place kidPlace = placeOf(to, s);
    
    switch (<p, kidPlace>) {
        case <<sql(), str dbName>, <sql(), dbName>>: {
          ; // nothing to be done, kids will be deleted as a result of cascade delete
        }

        case <<sql(), str dbName>, <sql(), str dbKid>>: {
          // NB this could be done based on the id of the entity to be deleted itself
          // but breakCrossLinkInSQL now deletes based on the kid's id
          steps += breakCrossLinkInSQL(dbName, ent, SQLExpr::placeholder(name="TO_DELETE"), "TO_DELETE", <p.name, "<x>", to, fromRole>, fromRole, to, toRole);
          SQLStat stat = delete(tableName(to), [
           where([equ(column(tableName(to), typhonId(to)), SQLExpr::placeholder(name="TO_DELETE"))])]);
        
          steps += [step(dbKid, sql(executeStatement(dbKid, pp(stat))), ("TO_DELETE": <p.name, "<x>", to, fromRole>))]; 
		}

        case <<sql(), str dbName>, <mongodb(), str dbKid>>: {
          // on dbName delete from junction table
          steps += breakCrossLinkInSQL(dbName, ent, SQLExpr::placeholder(name="TO_DELETE"), "TO_DELETE", field(p.name, "<x>", to, fromRole), fromRole, to, toRole);
          
          DBObject q = object([<"_id", DBObject::placeholder(name="TO_DELETE")>]);
          steps += [step(dbKid, mongo(deleteOne(dbKid, to, pp(q))), ("TO_DELETE": field(p.name, "<x>", to, fromRole)))];
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
          ; // nothing to be done, kids will be deleted as a result of nesting.
        }
        
        case <<mongodb(), str dbName>, <mongodb(), str dbKid>>: {
          // the refs on dbName, dissappear on delete
          // but we need to delete entities on the other mongo
          DBObject q = object([<"_id", DBObject::placeholder(name="TO_DELETE")>]);
          steps += [step(dbKid, mongo(deleteOne(dbKid, to, pp(q))), ("TO_DELETE": field(p.name, "<x>", to, fromRole)))];
        }

        case <<mongodb(), str dbName>, <sql(), str dbKid>>: {
          // the refs on dbName, dissappear on delete
          // but we need to delete entities on dbKid sql
          SQLStat stat = delete(tableName(to), [
           where([equ(column(tableName(to, typhonId(to))), SQLExpr::placeholder(name="TO_DELETE"))])]);
        
          steps += [step(dbKid, sql(executeStatement(dbKid, pp(stat))), ("TO_DELETE": field(p.name, "<x>", to, fromRole)))]; 
        }
    }
  }
  return steps;
}

list[Step] breakLinksWithParent(str ent, Param toBeDeleted, Place p, Schema s) {
  if (<str parent, _, str fromRole, str toRole, Cardinality toCard, ent, true> <- s.rels) {
    // NB: this assumes there's a unique owernship path
    Place parentPlace = placeOf(parent, s);
    
    switch (<parentPlace, p>) {
        case <<sql(), str dbName>, <sql(), dbName>>: {
          ; // nothing to be done, the parent link will be deleted via the foreinkey to the parent
          // when the object iself will be deleted 
        }

        case <<sql(), str dbParent>, <sql(), str dbKid>>: {
          return breakCrossLinkInSQL(dbParent, parent, SQLExpr::placeholder(name="TO_DELETE"), "TO_DELETE", toBeDeleted, fromRole, ent, toRole); 
		}

        case <<sql(), str dbParent>, <mongodb(), str dbKid>>: {
          return breakCrossLinkInSQL(dbParent, parent, SQLExpr::placeholder(name="TO_DELETE"), "TO_DELETE", toBeDeleted, fromRole, ent, toRole); 
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
          return breakCrossLinkInMongo(dbName, parent, DBObject::placeholder(name="TO_DELETE"), "TO_DELETE", toBeDeleted, fromRole, ent, toRole);
        }
        
        case <<mongodb(), str dbParent>, <mongodb(), str dbKid>>: {
          return breakCrossLinkInMongo(dbParent, parent, DBObject::placeholder(name="TO_DELETE"), "TO_DELETE", toBeDeleted, fromRole, ent, toRole);
        }

        case <<mongodb(), str dbParent>, <sql(), str dbKid>>: {
          return breakCrossLinkInMongo(dbParent, parent, DBObject::placeholder(name="TO_DELETE"), "TO_DELETE", toBeDeleted, fromRole, ent, toRole);
        }
    }
  }
  
  return [];
}

list[Step] removeFromManyReference(Place p, str ent, Id fld, {UUID ","}+ refs, str paramName, Param toBeUpdated, Schema s) {
   if (<ent, Cardinality fromCard,  str fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels, fromRole == "<fld>") {
      assert fromCard in {zero_many(), one_many()} : "Can only remove from many-valued things: <ent>.<fromRole> is not";
      
      Place targetPlace = placeOf(to, s);
      
      switch (<p, targetPlace>) {
        case <<sql(), str dbName>, <sql(), dbName>>: {
        
          
          // for each ref in refs, delete it (we cannot set the foreign key to null)
          
          str fk = fkName(ent, to, toRole == "" ? fromRole : toRole);
          list[SQLStat] stats = 
            [ delete(tableName(to),
              [where([equ(column(tableName(to), typhonId(to)), lit(evalExpr((Expr)`<UUID ref>`)))])]) | UUID ref <- refs ];
              
              
          return [step(dbName, sql(executeStatement(dbName, pp(stat))), (paramName: toBeUpdated)) 
                  | SQLStat stat <- stats ]; 
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          return [ *breakCrossLinkInSQL(myDb, ent, lit(text("<ref>"[1..])), paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return [ *breakCrossLinkInSQL(myDb, ent, lit(text("<ref>"[1..])), paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
          // Q: how to create nesting here?  --> we somehow need to disallow this (in the type checker?)
		  // if single: update me set fld to ref
		  // if multi: push/addToSet ref to fld on me
		  throw "Not yet implemented";
        }
        
        case <<mongodb(), str myDb>, <mongodb(), str dbKid>>: {
          // if single: update me set fld to ref
		  // if multi: push/addToSet ref to fld on me
		  return [ *breakCrossLinkInMongo(myDb, ent, DBObject::\value("<ref>"[1..]), paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
		  return [ *breakCrossLinkInMongo(myDb, ent, DBObject::\value("<ref>"[1..]), paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
        }
      }
    }
    // todo: require toRole to be != "" so that we have the canonical one.
    else if (<ent, _,  str fromRole, str toRole, Cardinality toCard, str to, false> <- s.rels, fromRole == "<fld>") {
      // a crossref.
      Place targetPlace = placeof(to, s);
      switch (<p, targetPlace>) {
        case <<sql(), str myDb>, <sql(), dbName>>: {
          return [ *breakCrossLinkInSQL(myDb, ent, lit(text("<ref>"[1..])), paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          return [ *breakCrossLinkInSQL(myDb, ent, lit(text("<ref>"[1..])), paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return [ *breakCrossLinkInSQL(myDb, ent, lit(text("<ref>"[1..])), paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
		  return [ *breakCrossLinkInMongo(myDb, ent, DBObject::\value("<ref>"[1..]), paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
        }
        
        case <<mongodb(), str myDb>, <mongodb(), str dbKid>>: {
		  return [ *breakCrossLinkInMongo(myDb, ent, DBObject::\value("<ref>"[1..]), paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
		  return [ *breakCrossLinkInMongo(myDb, ent, DBObject::\value("<ref>"[1..]), paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
        }
      }
    }
    else {
     throw "Could not find field <fld> in schema for <ent>";
    }
}


list[Step] addToManyReference(Place p, str ent, Id fld, {UUID ","}+ refs, str paramName, Param toBeUpdated, Schema s) {
  if (<ent, Cardinality fromCard,  str fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels, fromRole == "<fld>") {
      assert fromCard in {zero_many(), one_many()}: "Can only remove from many-valued things: <ent>.<fromRole> is not";
      
      Place targetPlace = placeOf(to, s);
      
      switch (<p, targetPlace>) {
        case <<sql(), str dbName>, <sql(), dbName>>: {
        
          
          // for each ref in refs, make it point to "me"
          // (the diff with updateManyReference, is we don't delete existing links)
          
          str fk = fkName(ent, to, toRole == "" ? fromRole : toRole);
          list[SQLStat] stats = 
            [ update(tableName(to),
              [ \set(columnName(tableName(to), fk), SQLExpr::placeholder(name=paramName)) ],
              [where([equ(column(tableName(to), typhonId(to)), lit(evalExpr((Expr)`<UUID ref>`)))])]) | UUID ref <- refs ];
              
              
          return [step(dbName, sql(executeStatement(dbName, pp(stat))), (paramName: toBeUpdated)) 
                  | SQLStat stat <- stats ]; 
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          //createCrossLinkInSQL(str dbName, str parent, str uuid, str fromRole, str to, str toRole)
          return [ *createCrossLinkInSQL(myDb, ent, "<ref>"[1..], paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return [ *createCrossLinkInSQL(myDb, ent, "<ref>"[1..], paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
          // Q: how to create nesting here?  --> we somehow need to disallow this (in the type checker?)
		  // if single: update me set fld to ref
		  // if multi: push/addToSet ref to fld on me
		  ;            
        }
        
        case <<mongodb(), str myDb>, <mongodb(), str dbKid>>: {
          // if single: update me set fld to ref
		  // if multi: push/addToSet ref to fld on me
		  //list[Step] createCrossLinkInMongo(str dbName, str parent, str uuid, str fromRole, Cardinality toCard) {
		  return [ *createCrossLinkInMongo(myDb, ent, "<ref>"[1..], paramName, toBeUpdated, fromRole, toCard, toBeUpdated) | UUID ref <- refs ];
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
		  return [ *createCrossLinkInMongo(myDb, ent, "<ref>"[1..], paramName, toBeUpdated, fromRole, toCard, toBeUpdated) | UUID ref <- refs ];
        }
      }
    }
    else if (<ent, Cardinality fromCard,  str fromRole, str toRole, Cardinality toCard, str to, false> <- s.rels, fromRole == "<fld>") {
      // a crossref.
      assert fromCard in {zero_many(), one_many()}: "Can only remove from many-valued things: <ent>.<fromRole> is not";
      
      Place targetPlace = placeof(to, s);
      switch (<p, targetPlace>) {
        case <<sql(), str myDb>, <sql(), dbName>>: {
          return [ *createCrossLinkInSQL(myDb, ent, "<ref>"[1..], paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          return [ *createCrossLinkInSQL(myDb, ent, "<ref>"[1..], paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return [ *createCrossLinkInSQL(myDb, ent, "<ref>"[1..], paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
          return [ *createCrossLinkInMongo(myDb, ent, "<ref>"[1..], paramName, toBeUpdated, fromRole, toCard, toBeUpdated) | UUID ref <- refs ];            
        }
        
        case <<mongodb(), str myDb>, <mongodb(), str dbKid>>: {
		  return [ *createCrossLinkInMongo(myDb, ent, "<ref>"[1..], paramName, toBeUpdated, fromRole, toCard, toBeUpdated) | UUID ref <- refs ];
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
          return [ *createCrossLinkInMongo(myDb, ent, "<ref>"[1..], paramName, toBeUpdated, fromRole, toCard, toBeUpdated) | UUID ref <- refs ];
        }
      }
    }
    else {
     throw "Could not find field <fld> in schema for <ent>";
    }
}

list[Step] updateManyReference(Place p, str ent, Id fld, {UUID ","}+ refs, str paramName, Param toBeUpdated, Schema s) {
  if (<ent, Cardinality fromCard,  str fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels, fromRole == "<fld>") {
      assert fromCard in {zero_many(), one_many()} : "Can only remove from many-valued things: <ent>.<fromRole> is not";
      
      Place targetPlace = placeOf(to, s);
      
      switch (<p, targetPlace>) {
        case <<sql(), str dbName>, <sql(), dbName>>: {
        
          // for each ref in refs, make it point to "me"
          // then delete all kids pointing to me *not in* refs
        
          str fk = fkName(ent, to, toRole == "" ? fromRole : toRole);
          list[SQLStat] stats = 
            //[
            //  update(tableName(to),
            //    [ \set(columnName(tableName(to), fk), lit(null())) ],
            //    [where([equ(column(tableName(to), fk), SQLExpr::placeholder(name="TO_UPDATE"))])])
            //] +
            [ update(tableName(to),
              [ \set(columnName(tableName(to), fk), SQLExpr::placeholder(name=paramName)) ],
              [where([equ(column(tableName(to), typhonId(to)), lit(evalExpr((Expr)`<UUID ref>`)))])]) | UUID ref <- refs ]
            + [
              delete(tableName(to), [
                where([ notIn(column(tableName(to), fk), [ evalExpr((Expr)`<UUID ref>`) | UUID ref <- refs ]) ])
              ])
            ] 
            ;
              
              
          return [step(dbName, sql(executeStatement(dbName, pp(stat))), (paramName: toBeUpdated)) 
                  | SQLStat stat <- stats ]; 
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          return updateSQLParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, paramName, toBeUpdated);
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return updateSQLParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, paramName, toBeUpdated);
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
          // Q: how to create nesting here?  --> we somehow need to disallow this (in the type checker?)
		  // if single: update me set fld to ref
		  // if multi: push/addToSet ref to fld on me
		  ;            
        }
        
        case <<mongodb(), str myDb>, <mongodb(), str dbKid>>: {
          // if single: update me set fld to ref
		  // if multi: push/addToSet ref to fld on me
		  return updateMongoParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, paramName, toBeUpdated);
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
          return updateMongoParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, paramName, toBeUpdated);
        }
      }
    }
    else if (<ent, _,  str fromRole, str toRole, Cardinality toCard, str to, false> <- s.rels, fromRole == "<fld>") {
      // a crossref.
      Place targetPlace = placeof(to, s);
      switch (<p, targetPlace>) {
        case <<sql(), str myDb>, <sql(), dbName>>: {
          return updateSQLParent(myDb, ent, fromRole, to, toRole, toCard, refs, paramName, toBeUpdated);
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          return updateSQLParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, paramName, toBeUpdated);
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return updateSQLParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, paramName, toBeUpdated);
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
          return updateMongoParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, paramName, toBeUpdated);            
        }
        
        case <<mongodb(), str myDb>, <mongodb(), str dbKid>>: {
		  return updateMongoParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, paramName, toBeUpdated);
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
          return updateMongoParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, paramName, toBeUpdated);
        }
      }
    }
    else {
     throw "Could not find field <fld> in schema for <ent>";
    }
}

list[Step] updateReference(Place p, str ent, Id fld, UUID ref, str paramName, Param toBeUpdated, Schema s) {
    if (<ent, _,  str fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels, fromRole == "<fld>") {
      Place targetPlace = placeof(to, s);
      switch (<p, targetPlace>) {
        case <<sql(), str dbName>, <sql(), dbName>>: {
          str fk = fkName(ent, to, toRole == "" ? fromRole : toRole);
          SQLStat stat = update(tableName(to),
              [ \set(columnName(tableName(to), fk), SQLExpr::placeholder(name=paramName)) ],
              [where([equ(column(tableName(to), typhonId(to)), lit(evalExpr((Expr)`<UUID ref>`)))])]);
          return [step(dbName, sql(executeStatement(dbName, pp(stat))), (paramName: toBeUpdated))]; 
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          return updateSQLParent(myDb, ent, fromRole, to, toRole, toCard, ref, paramName, toBeUpdated);
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return updateSQLParent(myDb, ent, fromRole, to, toRole, toCard, ref, paramName, toBeUpdated);
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
          // Q: how to create nesting here?  --> we somehow need to disallow this (in the type checker?)
		  // if single: update me set fld to ref
		  // if multi: push/addToSet ref to fld on me
		  ;            
        }
        
        case <<mongodb(), str myDb>, <mongodb(), str dbKid>>: {
          // if single: update me set fld to ref
		  // if multi: push/addToSet ref to fld on me
		  return updateMongoParent(myDb, ent, fromRole, to, toRole, toCard, ref, paramName, toBeUpdated);
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
          return updateMongoParent(myDb, ent, fromRole, to, toRole, toCard, ref, paramName, toBeUpdated);
        }
      }
    }
    else if (<ent, _,  str fromRole, str toRole, Cardinality toCard, str to, false> <- s.rels, fromRole == "<fld>") {
      // a crossref.
      Place targetPlace = placeof(to, s);
      switch (<p, targetPlace>) {
        case <<sql(), str myDb>, <sql(), dbName>>: {
           return updateSQLParent(myDb, ent, fromRole, to, toRole, toCard, ref, paramName, toBeUpdated);
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          return updateSQLParent(myDb, ent, fromRole, to, toRole, toCard, ref, paramName, toBeUpdated);
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return updateSQLParent(myDb, ent, fromRole, to, toRole, toCard, ref, paramName, toBeUpdated);
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
          return updateMongoParent(myDb, ent, fromRole, to, toRole, toCard, ref, paramName, toBeUpdated);            
        }
        
        case <<mongodb(), str myDb>, <mongodb(), str dbKid>>: {
		  return updateMongoParent(myDb, ent, fromRole, to, toRole, toCard, ref, paramName, toBeUpdated);
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
          return updateMongoParent(myDb, ent, fromRole, to, toRole, toCard, ref, paramName, toBeUpdated);
        }
      }
    }
    else {
     throw "Could not find field <fld> in schema for <ent>";
    }
}

list[Step] updateSQLParentManyKids(str dbName, str ent, str fromRole, str to, str toRole, Cardinality toCard, {UUID ","}+ refs, str paramName, Param toBeUpdated) {
  str parentFk = junctionFkName(ent, fromRole);
  str kidFk = junctionFkName(to, toRole);
  str fkTbl = junctionTableName(ent, fromRole, to, toRole);
  
  list[SQLStat] stats = [
        // first delete any old ones (kids/targets)
        delete(fkTbl, [where([
          equ(column(fkTbl, parentFk), SQLExpr::placeholder(name=paramName))])
        ]),
        // then insert it for each ref
        *[
          \insert(fkTbl, [parentFk, kidFk], [Value::placeholder(name=paramName),  evalExpr((Expr)`<UUID ref>`)])
            | UUID ref <- refs ]
      ];
  
  return [step(dbName, sql(executeStatement(dbName, pp(stat))), (paramName: toBeUpdated)) | SQLStat stat <- stats ];
}


list[Step] updateSQLParent(str dbName, str ent, str fromRole, str to, str toRole, Cardinality toCard, UUID ref, str paramName, Param toBeUpdated) {
  // this code is very similar to createCrossLInk..., but that function
  // assumes it is a *new* link.
  str parentFk = junctionFkName(ent, fromRole);
  str kidFk = junctionFkName(to, toRole);
  str fkTbl = junctionTableName(ent, fromRole, to, toRole);
  
  // update junctiontable so that fk points to me for ref
  
  list[SQLStat] stats = [];
  if (toCard in {one_many(), zero_many()}) {
      stats = [
        // NB: we have to do delete + insert, because we can't use
        // update as it presumes that it is already there;
        // in this case: if it's not, delete will be a no-op.
        // first delete the old one, if any
        delete(fkTbl, [where([
          equ(column(fkTbl, parentFk), SQLExpr::placeholder(name=paramName)),
          equ(column(fkTbl, kidFk), lit(evalExpr((Expr)`<UUID ref>`)))])
        ]),
        // then insert it
        \insert(fkTbl, [parentFk, kidFk], [Value::placeholder(name=paramName),  evalExpr((Expr)`<UUID ref>`)])
      ];
  }
  else {
    stats = [
      // first delete *any* old one, if any
      delete(fkTbl, [where([equ(column(fkTbl, parentFk), SQLExpr::placeholder(name=paramName))])]),
      // then insert it
      \insert(fkTbl, [parentFk, kidFk], [Value::placeholder(name=paramName),  evalExpr((Expr)`<UUID ref>`)])
    ];
  }
	          
  return [step(dbName, sql(executeStatement(dbName, pp(stat))), (paramName: toBeUpdated)) | SQLStat stat <- stats ];
}

list[Step] updateMongoParentManyKids(str dbName, str ent, str fromRole, str to, str toRole, Cardinality toCard, {UUID ","}+ refs, str param, Param toBeUpdated) {
  DBObject q = object([<"_id", DBObject::placeholder(name=param)>]); // unfortunately we cannot reuse expr2obj here...
  
  DBObject makeKid(UUID ref) = \value("<ref>"[1..]);
  
  DBObject u = object([<"$set", object([<fromRole, array([ makeKid(ref) | UUID ref <- refs ])>])>]);
  
  return [step(dbName, mongo(findAndUpdateOne(dbName, parent, pp(q), pp(u))), (param: toBeUpdated))];
}

list[Step] updateMongoParent(str dbName, str ent, str fromRole, str to, str toRole, Cardinality toCard, UUID ref, str param, Param toBeUpdated) { 
  DBObject q = object([<"_id", DBObject::placeholder(name=param)>]); // unfortunately we cannot reuse expr2obj here...
  DBObject kid = \value("<ref>"[1..]);
  DBObject u = object([<"$set", object([<fromRole, kid>])>]);
  if (toCard in {one_many(), zero_many()}) {
    u = object([<"$addToSet", object([<fromRole, kid>])>]);
  }
  return [step(dbName, mongo(findAndUpdateOne(dbName, parent, pp(q), pp(u))), (param: toBeUpdated))];
}


list[Step] breakCrossLinkInSQL(str dbName, str parent, SQLExpr kid, str param, Param kidField, str fromRole, str to, str toRole) {
  SQLStat parentStat = 
    \delete(junctionTableName(parent, fromRole, to, toRole),[
      where([
        equ(column(junctionTableName(parent, fromRole, to, toRole), junctionFkName(to, toRole)), kid)
      ])]);
   return [step(dbName, sql(executeStatement(dbName, pp(parentStat))), (param: kidField))];         
}

list[Step] breakCrossLinkInMongo(str dbName, str parent, DBObject kid, str kidParam, Param kidField, str fromRole, str to, str toRole) {
  // findAndUpdateOne({}, {$pull: {fromRole: <kidParam>}});
  DBObject q = object([]);
  DBObject u = object([<"$pull", object([<fromRole, kid>])>]);
  return [step(dbName, mongo(findAndUpdateOne(dbName, parent, pp(q), pp(u))), (kidParam: kidField))];
}


list[Step] createCrossLinkInSQL(str dbName, str parent, str uuid, str kidParam, Param kidValue, str fromRole, str to, str toRole) {
  SQLStat parentStat = 
    \insert(junctionTableName(parent, fromRole, to, toRole)
            , [junctionFkName(to, toRole), junctionFkName(parent, fromRole)]
            , [text(uuid), Value::placeholder(name=kidParam)]);
   return [step(dbName, sql(executeStatement(dbName, pp(parentStat))), (kidParam: kidValue))];         
}


list[Step] createCrossLinkInMongo(str dbName, str parent, str uuid, str kidParam, Param kidValue, str fromRole, Cardinality toCard) {
  DBObject q = object([<"_id", \value(uuid)>]);
  DBObject u = object([<"$set", object([<fromRole, DBObject::placeholder(name=kidParam)>])>]);
  if (toCard in {one_many(), zero_many()}) {
    u = object([<"$addToSet", object([<fromRole, DBObject::placeholder(name=kidParam)>])>]);
  }
  return [step(dbName, mongo(findAndUpdateOne(dbName, parent, pp(q), pp(u))), (kidParam: kidValue))];
}

list[Step] compileQuery(r:(Request)`<Query q>`, p:<sql(), str dbName>, Schema s) {
  r = expandNavigation(addWhereIfAbsent(r), s);
  println("COMPILING: <r>");
  <sqlStat, params> = compile2sql(r, s, p);
  // hack
  if (sqlStat.exprs == []) {
    return [];
  }
  return [step(dbName, sql(executeQuery(dbName, pp(sqlStat))), params)];
}

list[Step] compileQuery(r:(Request)`<Query q>`, p:<mongodb(), str dbName>, Schema s) {
  <methods, params> = compile2mongo(r, s, p);
  for (str coll <- methods) {
    // TODO: signal if multiple!
    return [step(dbName, mongo(find(dbName, coll, pp(methods[coll].query), pp(methods[coll].projection))), params)];
  }
  return [];
}

void smokeScript() {
  s = schema({
    <"Person", zero_many(), "reviews", "user", \one(), "Review", true>,
    <"Person", zero_many(), "cash", "owner", \one(), "Cash", true>,
    <"Review", \one(), "user", "reviews", \zero_many(), "Person", false>,
    <"Review", \one(), "comment", "owner", \zero_many(), "Comment", true>,
    <"Comment", zero_many(), "replies", "owner", \zero_many(), "Comment", true>
  }, {
    <"Person", "name", "String">,
    <"Person", "age", "int">,
    <"Cash", "amount", "int">,
    <"Review", "text", "String">,
    <"Comment", "contents", "String">,
    <"Reply", "reply", "String">
  },
  placement = {
    <<sql(), "Inventory">, "Person">,
    <<sql(), "Inventory">, "Cash">,
    <<mongodb(), "Reviews">, "Review">,
    <<mongodb(), "Reviews">, "Comment">
  } 
  );
  
  void smokeIt(Request q) {
    println("REQUEST: `<q>`");
    iprintln(request2script(q, s));
  }
  
  smokeIt((Request)`from Person p, Review r select r.text, p.name where p.name == "Pablo", p.reviews == r`);  
  smokeIt((Request)`from Person p, Review r select r.text, p.name where p.name == "Pablo", p.reviews == r`);  

  smokeIt((Request)`from Person u, Review r select r where r.user == u, u.name == "Pablo"`);
  
  

  smokeIt((Request)`delete Review r`);

  
  smokeIt((Request)`delete Review r where r.text == "Bad"`);
  
  smokeIt((Request)`delete Comment c where c.contents == "Bad"`);
  
  smokeIt((Request)`delete Person p`);

  smokeIt((Request)`delete Person p where p.name == "Pablo"`);
  
  smokeIt((Request)`update Person p set {name: "Pablo"}`);

  smokeIt((Request)`update Person p set {name: "Pablo", age: 23}`);


  smokeIt((Request)`update Person p where p.name == "Pablo" set {reviews +: [#abc, #cde]}`);

  smokeIt((Request)`update Person p where p.name == "Pablo" set {reviews -: [#abc, #cde]}`);

  smokeIt((Request)`update Person p where p.name == "Pablo" set {reviews: [#abc, #cde]}`);

  smokeIt((Request)`update Review r set {text: "bad"}`);

  smokeIt((Request)`update Review r where r.text == "Good" set {text: "Bad"}`);

  smokeIt((Request)`update Person p set {name: "Pablo", cash: [#abc, #cde]}`);

  smokeIt((Request)`update Person p set {name: "Pablo", cash +: [#abc, #cde]}`);

  smokeIt((Request)`update Person p set {name: "Pablo", cash -: [#abc, #cde]}`);

  smokeIt((Request)`update Person p where p.name == "Pablo" set {reviews -: [#abc, #cde]}`);

  smokeIt((Request)`delete Person p where p.name == "Pablo"`);
  
  smokeIt((Request)`insert Person {name: "Pablo", age: 23}`);
  smokeIt((Request)`insert Person {name: "Pablo", age: 23, reviews: #abc, reviews: #cdef}`);

  smokeIt((Request)`insert Review {text: "Bad"}`);

  
  smokeIt((Request)`insert Review {text: "Bad"} into #pablo.reviews`);
  
  smokeIt((Request)`insert Comment {contents: "Bad"} into #somereview.comment`);
  
  
}  
