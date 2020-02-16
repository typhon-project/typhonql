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
      
      Field toBeUpdated = <p.name, "<x>", ent, "@id">;
       
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


      for ((KeyVal)`<Id fld>: <UUID ref>` <- kvs) {
        scr.steps += updateReference(p, ent, fld, ref, toBeUpdated, s);
      }

      for ((KeyVal)`<Id fld>: [<{UUID ","}+ refs>]` <- kvs) {
        scr.steps += updateManyReference(p, ent, fld, refs, toBeUpdated, s);
      }

      
      for ((KeyVal)`<Id fld> +: [<{UUID ","}+ refs>]` <- kvs) {
        scr.steps += addToManyReference(p, ent, fld, refs, toBeUpdated, s);
      }
      
      for ((KeyVal)`<Id fld> -: [<{UUID ","}+ refs>]` <- kvs) {
        scr.steps += removeFromManyReference(p, ent, fld, refs, toBeUpdated, s);
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
      
      Field fieldToBeDeleted = <p.name, "<x>", "<e>", "@id">;
     
      
      // then, we're gonna break parent links if the entity to be deleted is owned
      if (<str parent, _, str fromRole, str toRole, Cardinality toCard, ent, true> <- s.rels) {
        // NB: this assumes there's a unique owernship path
        Place parentPlace = placeOf(parent, s);
        
        switch (<parentPlace, p>) {
            case <<sql(), str dbName>, <sql(), dbName>>: {
              ; // nothing to be done, the parent link will be deleted via the foreinkey to the parent
              // when the object iself will be deleted 
            }

            case <<sql(), str dbParent>, <sql(), str dbKid>>: {
              scr.steps += breakCrossLinkInSQL(dbParent, parent, SQLExpr::placeholder(name="TO_DELETE"), "TO_DELETE", fieldToBeDeleted, fromRole, ent, toRole); 
			}

            case <<sql(), str dbParent>, <mongodb(), str dbKid>>: {
              scr.steps += breakCrossLinkInSQL(dbParent, parent, SQLExpr::placeholder(name="TO_DELETE"), "TO_DELETE", fieldToBeDeleted, fromRole, ent, toRole); 
			}
            
            case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
              scr.steps += breakCrossLinkInMongo(dbName, parent, DBObject::placeholder(name="TO_DELETE"), "TO_DELETE", fieldToBeDeleted, fromRole, ent, toRole);
            }
            
            case <<mongodb(), str dbParent>, <mongodb(), str dbKid>>: {
              scr.steps += breakCrossLinkInMongo(dbParent, parent, DBObject::placeholder(name="TO_DELETE"), "TO_DELETE", fieldToBeDeleted, fromRole, ent, toRole);
            }

            case <<mongodb(), str dbParent>, <sql(), str dbKid>>: {
              scr.steps += breakCrossLinkInMongo(dbParent, parent, DBObject::placeholder(name="TO_DELETE"), "TO_DELETE", fieldToBeDeleted, fromRole, ent, toRole);
            }
        }
      }
      
      // then we (cascade) delete kids that are not automatic (e.g. cross db).
      
      for (<ent, _, str fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels, placeOf(to, s) != p) {
        Place kidPlace = placeOf(to, s);
        
        switch (<p, kidPlace>) {
            case <<sql(), str dbName>, <sql(), dbName>>: {
              ; // nothing to be done, kids will be deleted as a result of cascade delete
            }

            case <<sql(), str dbName>, <sql(), str dbKid>>: {
              // NB this could be done based on the id of the entity to be deleted itself
              // but breakCrossLinkInSQL now deletes based on the kid's id
              scr.steps += breakCrossLinkInSQL(dbName, ent, SQLExpr::placeholder(name="TO_DELETE"), "TO_DELETE", <p.name, "<x>", to, fromRole>, fromRole, to, toRole);
              SQLStat stat = delete(tableName(to), [
               where([equ(column(tableName(to), typhonId(to)), SQLExpr::placeholder(name="TO_DELETE"))])]);
            
              scr.steps += [step(dbKid, sql(executeStatement(dbKid, pp(stat))), ("TO_DELETE": <p.name, "<x>", to, fromRole>))]; 
			}

            case <<sql(), str dbName>, <mongodb(), str dbKid>>: {
              // on dbName delete from junction table
              scr.steps += breakCrossLinkInSQL(dbName, ent, SQLExpr::placeholder(name="TO_DELETE"), "TO_DELETE", <p.name, "<x>", to, fromRole>, fromRole, to, toRole);
              
              DBObject q = object([<"_id", DBObject::placeholder(name="TO_DELETE")>]);
              scr.steps += [step(dbKid, mongo(deleteOne(dbKid, to, pp(q))), ("TO_DELETE": <p.name, "<x>", to, fromRole>))];
			}
            
            case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
              ; // nothing to be done, kids will be deleted as a result of nesting.
            }
            
            case <<mongodb(), str dbName>, <mongodb(), str dbKid>>: {
              // the refs on dbName, dissappear on delete
              // but we need to delete entities on the other mongo
              DBObject q = object([<"_id", DBObject::placeholder(name="TO_DELETE")>]);
              scr.steps += [step(dbKid, mongo(deleteOne(dbKid, to, pp(q))), ("TO_DELETE": <p.name, "<x>", to, fromRole>))];
            }

            case <<mongodb(), str dbName>, <sql(), str dbKid>>: {
              // the refs on dbName, dissappear on delete
              // but we need to delete entities on dbKid sql
              SQLStat stat = delete(tableName(to), [
               where([equ(column(tableName(to, typhonId(to))), SQLExpr::placeholder(name="TO_DELETE"))])]);
            
              scr.steps += [step(dbKid, sql(executeStatement(dbKid, pp(stat))), ("TO_DELETE": <p.name, "<x>", to, fromRole>))]; 
            }
        }
      }
      
      // then delete the entity itself
      
      switch (p) {
        case <sql(), str dbName>: {
          SQLStat stat = delete(tableName(ent), [
            where([
             equ(column(tableName(ent), typhonId(ent)), SQLExpr::placeholder(name="TO_DELETE"))
            ])]);
            
          scr.steps += [step(dbName, sql(executeStatement(dbName, pp(stat))), ("TO_DELETE": fieldToBeDeleted))];  
        }
        
        case <mongodb(), str dbName>: {
          DBObject q = object([<"_id", DBObject::placeholder(name="TO_DELETE")>]);
          scr.steps += [step(dbName, mongo(deleteOne(dbName, ent, pp(q))),  ("TO_DELETE": fieldToBeDeleted))];
        }
      }
      
      return scr;
      
    }

    case (Request)`insert <EId e> { <{KeyVal ","}* kvs> }`: {
      Place p = placeOf("<e>", s);
      switch (p) {
        case <sql(), str dbName>: {
          <stats, params> = insert2sql(r, s, p);
          return script([ step(dbName, sql(executeStatement(dbName, pp(stat))), params) | SQLStat stat <- stats ]);
        }

        case <mongodb(), str dbName>: {
          return script(insert2mongo(r, s, p));
        }
      }
    }
  
    case (Request)`insert <EId e> { <{KeyVal ","}* kvs> } into <UUID owner>.<Id field>`: {
      Place p = placeOf("<e>", s);
      if (<str parent, _, str fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels, fromRole == "<field>", to == "<e>") {
        Place parentPlace = placeOf(parent, s);
        str uuid = "<owner>"[1..];
        switch (<parentPlace, p>) {
            case <<sql(), str dbName>, <sql(), dbName>>: {
               str fk = fkName(parent, to, toRole == "" ? fromRole : toRole);
 			   <stats, params> = insert2sql((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, s, p, parent = <fk, "<owner>">);
 			   return script([step(dbName, sql(executeStatement(dbName, pp(stat))), params) | SQLStat stat <- stats ]);
            }

            case <<sql(), str dbParent>, <sql(), str dbKid>>: {
              <stats, params> = insert2sql((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, s, p);
              return script(createCrossLinkInSQL(dbParent, parent, uuid, fromRole, to, toRole)
                + [ step(dbKid, sql(executeStatement(dbKid, pp(stat))), params) | SQLStat stat <- stats ]);
			}

            case <<sql(), str dbParent>, <mongodb(), str dbKid>>: {
              return script(createCrossLinkInSQL(dbParent, parent, uuid, fromRole, to, toRole)
                + insert2mongo((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, s, p));          
			  
			}
            
            case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
              return script(createCrossLinkInMongo(dbName, parent, uuid, fromRole, toCard)
                 + insert2mongo((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, s, p));
            }
            
            case <<mongodb(), str dbParent>, <mongodb(), str dbKid>>: {
              return script(createCrossLinkInMongo(dbParent, parent, uuid, fromRole, toCard) 
                + insert2mongo((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, s, p));
            }

            case <<mongodb(), str dbParent>, <sql(), str dbKid>>: {
              <stats, params> = insert2sql((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, s, p);
              return script(createCrossLinkInMongo(dbParent, parent, uuid, fromRole, toCard) 
                + [ step(dbKid, sql(executeStatement(dbKid, pp(stat))), params) | SQLStat stat <- stats ]);
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

list[Step] removeFromManyReference(Place p, str ent, Id fld, {UUID ","}+ refs, Field toBeUpdated, Schema s) {
   if (<ent, _,  str fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels, fromRole == "<fld>") {
      //assert toCard in {zero_many(), one_many()};
      
      Place targetPlace = placeOf(to, s);
      
      switch (<p, targetPlace>) {
        case <<sql(), str dbName>, <sql(), dbName>>: {
        
          
          // for each ref in refs, delete it (we cannot set the foreign key to null)
          
          str fk = fkName(ent, to, toRole == "" ? fromRole : toRole);
          list[SQLStat] stats = 
            [ delete(tableName(to),
              [where([equ(column(tableName(to), typhonId(to)), lit(evalExpr((Expr)`<UUID ref>`)))])]) | UUID ref <- refs ];
              
              
          return [step(dbName, sql(executeStatement(dbName, pp(stat))), ("TO_UPDATE": toBeUpdated)) 
                  | SQLStat stat <- stats ]; 
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          // str dbName, str parent, str kidParam, Field kidField, str fromRole, str to, str toRole
          return [ *breakCrossLinkInSQL(myDb, ent, lit(text("<ref>"[1..])), "TO_UPDATE", toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return [ *breakCrossLinkInSQL(myDb, ent, lit(text("<ref>"[1..])), "TO_UPDATE", toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
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
		  //breakCrossLinkInMongo(str dbName, str parent, DBObject kid, str kidParam, Field kidField, str fromRole, str to, str toRole)
		  return [ *breakCrossLinkInMongo(myDb, ent, DBObject::\value("<ref>"[1..]), "TO_UPDATE", toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
		  return [ *breakCrossLinkInMongo(myDb, ent, DBObject::\value("<ref>"[1..]), "TO_UPDATE", toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
        }
      }
    }
    else if (<ent, _,  str fromRole, str toRole, Cardinality toCard, str to, false> <- s.rels, fromRole == "<fld>") {
      // a crossref.
      Place targetPlace = placeof(to, s);
      switch (<p, targetPlace>) {
        case <<sql(), str myDb>, <sql(), dbName>>: {
          return [ *breakCrossLinkInSQL(myDb, ent, lit(text("<ref>"[1..])), "TO_UPDATE", toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          return [ *breakCrossLinkInSQL(myDb, ent, lit(text("<ref>"[1..])), "TO_UPDATE", toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return [ *breakCrossLinkInSQL(myDb, ent, lit(text("<ref>"[1..])), "TO_UPDATE", toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
		  return [ *breakCrossLinkInMongo(myDb, ent, DBObject::\value("<ref>"[1..]), "TO_UPDATE", toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
        }
        
        case <<mongodb(), str myDb>, <mongodb(), str dbKid>>: {
		  return [ *breakCrossLinkInMongo(myDb, ent, DBObject::\value("<ref>"[1..]), "TO_UPDATE", toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
		  return [ *breakCrossLinkInMongo(myDb, ent, DBObject::\value("<ref>"[1..]), "TO_UPDATE", toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
        }
      }
    }
    else {
     throw "Could not find field <fld> in schema for <ent>";
    }
}


list[Step] addToManyReference(Place p, str ent, Id fld, {UUID ","}+ refs, Field toBeUpdated, Schema s) {
  if (<ent, _,  str fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels, fromRole == "<fld>") {
      //assert toCard in {zero_many(), one_many()};
      
      Place targetPlace = placeOf(to, s);
      
      switch (<p, targetPlace>) {
        case <<sql(), str dbName>, <sql(), dbName>>: {
        
          
          // for each ref in refs, make it point to "me"
          // (the diff with updateManyReference, is we don't delete existing links)
          
          str fk = fkName(ent, to, toRole == "" ? fromRole : toRole);
          list[SQLStat] stats = 
            [ update(tableName(to),
              [ \set(columnName(tableName(to), fk), SQLExpr::placeholder(name="TO_UPDATE")) ],
              [where([equ(column(tableName(to), typhonId(to)), lit(evalExpr((Expr)`<UUID ref>`)))])]) | UUID ref <- refs ];
              
              
          return [step(dbName, sql(executeStatement(dbName, pp(stat))), ("TO_UPDATE": toBeUpdated)) 
                  | SQLStat stat <- stats ]; 
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          //createCrossLinkInSQL(str dbName, str parent, str uuid, str fromRole, str to, str toRole)
          return [ *createCrossLinkInSQL(myDb, ent, "<ref>"[1..], fromRole, to, toRole) | UUID ref <- refs ];
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return [ *createCrossLinkInSQL(myDb, ent, "<ref>"[1..], fromRole, to, toRole) | UUID ref <- refs ];
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
		  return [ *createCrossLinkInMongo(myDb, ent, "<ref>"[1..], fromRole, toCard, toBeUpdated) | UUID ref <- refs ];
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
		  return [ *createCrossLinkInMongo(myDb, ent, "<ref>"[1..], fromRole, toCard, toBeUpdated) | UUID ref <- refs ];
        }
      }
    }
    else if (<ent, _,  str fromRole, str toRole, Cardinality toCard, str to, false> <- s.rels, fromRole == "<fld>") {
      // a crossref.
      Place targetPlace = placeof(to, s);
      switch (<p, targetPlace>) {
        case <<sql(), str myDb>, <sql(), dbName>>: {
          return [ *createCrossLinkInSQL(myDb, ent, "<ref>"[1..], fromRole, to, toRole) | UUID ref <- refs ];
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          return [ *createCrossLinkInSQL(myDb, ent, "<ref>"[1..], fromRole, to, toRole) | UUID ref <- refs ];
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return [ *createCrossLinkInSQL(myDb, ent, "<ref>"[1..], fromRole, to, toRole) | UUID ref <- refs ];
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
          return [ *createCrossLinkInMongo(myDb, ent, "<ref>"[1..], fromRole, toCard, toBeUpdated) | UUID ref <- refs ];            
        }
        
        case <<mongodb(), str myDb>, <mongodb(), str dbKid>>: {
		  return [ *createCrossLinkInMongo(myDb, ent, "<ref>"[1..], fromRole, toCard, toBeUpdated) | UUID ref <- refs ];
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
          return [ *createCrossLinkInMongo(myDb, ent, "<ref>"[1..], fromRole, toCard, toBeUpdated) | UUID ref <- refs ];
        }
      }
    }
    else {
     throw "Could not find field <fld> in schema for <ent>";
    }
}

list[Step] updateManyReference(Place p, str ent, Id fld, {UUID ","}+ refs, Field toBeUpdated, Schema s) {
  if (<ent, _,  str fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels, fromRole == "<fld>") {
      //assert toCard in {zero_many(), one_many()};
      
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
              [ \set(columnName(tableName(to), fk), SQLExpr::placeholder(name="TO_UPDATE")) ],
              [where([equ(column(tableName(to), typhonId(to)), lit(evalExpr((Expr)`<UUID ref>`)))])]) | UUID ref <- refs ]
            + [
              delete(tableName(to), [
                where([ notIn(column(tableName(to), fk), [ evalExpr((Expr)`<UUID ref>`) | UUID ref <- refs ]) ])
              ])
            ] 
            ;
              
              
          return [step(dbName, sql(executeStatement(dbName, pp(stat))), ("TO_UPDATE": toBeUpdated)) 
                  | SQLStat stat <- stats ]; 
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          return updateSQLParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, "TO_UPDATE", toBeUpdated);
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return updateSQLParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, "TO_UPDATE", toBeUpdated);
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
		  return updateMongoParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, "TO_UPDATE", toBeUpdated);
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
          return updateMongoParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, "TO_UPDATE", toBeUpdated);
        }
      }
    }
    else if (<ent, _,  str fromRole, str toRole, Cardinality toCard, str to, false> <- s.rels, fromRole == "<fld>") {
      // a crossref.
      Place targetPlace = placeof(to, s);
      switch (<p, targetPlace>) {
        case <<sql(), str myDb>, <sql(), dbName>>: {
          return updateSQLParent(myDb, ent, fromRole, to, toRole, toCard, refs, "TO_UPDATE", toBeUpdated);
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          return updateSQLParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, "TO_UPDATE", toBeUpdated);
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return updateSQLParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, "TO_UPDATE", toBeUpdated);
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
          return updateMongoParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, "TO_UPDATE", toBeUpdated);            
        }
        
        case <<mongodb(), str myDb>, <mongodb(), str dbKid>>: {
		  return updateMongoParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, "TO_UPDATE", toBeUpdated);
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
          return updateMongoParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, "TO_UPDATE", toBeUpdated);
        }
      }
    }
    else {
     throw "Could not find field <fld> in schema for <ent>";
    }
}

list[Step] updateReference(Place p, str ent, Id fld, UUID ref, Field toBeUpdated, Schema s) {
    if (<ent, _,  str fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels, fromRole == "<fld>") {
      Place targetPlace = placeof(to, s);
      switch (<p, targetPlace>) {
        case <<sql(), str dbName>, <sql(), dbName>>: {
          str fk = fkName(ent, to, toRole == "" ? fromRole : toRole);
          SQLStat stat = update(tableName(to),
              [ \set(columnName(tableName(to), fk), SQLExpr::placeholder(name="TO_UPDATE")) ],
              [where([equ(column(tableName(to), typhonId(to)), lit(evalExpr((Expr)`<UUID ref>`)))])]);
          return [step(dbName, sql(executeStatement(dbName, pp(stat))), ("TO_UPDATE": toBeUpdated))]; 
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          return updateSQLParent(myDb, ent, fromRole, to, toRole, toCard, ref, "TO_UPDATE", toBeUpdated);
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return updateSQLParent(myDb, ent, fromRole, to, toRole, toCard, ref, "TO_UPDATE", toBeUpdated);
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
		  return updateMongoParent(myDb, ent, fromRole, to, toRole, toCard, ref, "TO_UPDATE", toBeUpdated);
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
          return updateMongoParent(myDb, ent, fromRole, to, toRole, toCard, ref, "TO_UPDATE", toBeUpdated);
        }
      }
    }
    else if (<ent, _,  str fromRole, str toRole, Cardinality toCard, str to, false> <- s.rels, fromRole == "<fld>") {
      // a crossref.
      Place targetPlace = placeof(to, s);
      switch (<p, targetPlace>) {
        case <<sql(), str myDb>, <sql(), dbName>>: {
           return updateSQLParent(myDb, ent, fromRole, to, toRole, toCard, ref, "TO_UPDATE", toBeUpdated);
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          return updateSQLParent(myDb, ent, fromRole, to, toRole, toCard, ref, "TO_UPDATE", toBeUpdated);
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return updateSQLParent(myDb, ent, fromRole, to, toRole, toCard, ref, "TO_UPDATE", toBeUpdated);
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
          return updateMongoParent(myDb, ent, fromRole, to, toRole, toCard, ref, "TO_UPDATE", toBeUpdated);            
        }
        
        case <<mongodb(), str myDb>, <mongodb(), str dbKid>>: {
		  return updateMongoParent(myDb, ent, fromRole, to, toRole, toCard, ref, "TO_UPDATE", toBeUpdated);
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
          return updateMongoParent(myDb, ent, fromRole, to, toRole, toCard, ref, "TO_UPDATE", toBeUpdated);
        }
      }
    }
    else {
     throw "Could not find field <fld> in schema for <ent>";
    }
}

list[Step] updateSQLParentManyKids(str dbName, str ent, str fromRole, str to, str toRole, Cardinality toCard, {UUID ","}+ refs, str param, Field toBeUpdated) {
  str parentFk = junctionFkName(ent, fromRole);
  str kidFk = junctionFkName(to, toRole);
  str fkTbl = junctionTableName(ent, fromRole, to, toRole);
  
  list[SQLStat] stats = [
        // first delete any old ones (kids/targets)
        delete(fkTbl, [where([
          equ(column(fkTbl, parentFk), SQLExpr::placeholder(name=param))])
        ]),
        // then insert it for each ref
        *[
          \insert(fkTbl, [parentFk, kidFk], [Value::placeholder(name=param),  evalExpr((Expr)`<UUID ref>`)])
            | UUID ref <- refs ]
      ];
  
  return [step(dbName, sql(executeStatement(dbName, pp(stat))), (param: toBeUpdated)) | SQLStat stat <- stats ];
}


list[Step] updateSQLParent(str dbName, str ent, str fromRole, str to, str toRole, Cardinality toCard, UUID ref, str param, Field toBeUpdated) {
  // this code is very similar to createCrossLInk..., but that function
  // assumes it is a *new* link.
  str parentFk = junctionFkName(ent, fromRole);
  str kidFk = junctionFkName(to, toRole);
  str fkTbl = junctionTableName(ent, fromRole, to, toRole);
  
  // update junctiontable so that fk points to me for ref
  
  list[SQLStat] stats = [];
  if (toCard in {one_many(), zero_many()}) {
      stats = [
        // first delete the old one, if any
        delete(fkTbl, [where([
          equ(column(fkTbl, parentFk), SQLExpr::placeholder(name=param)),
          equ(column(fkTbl, kidFk), lit(evalExpr((Expr)`<UUID ref>`)))])
        ]),
        // then insert it
        \insert(fkTbl, [parentFk, kidFk], [Value::placeholder(name=param),  evalExpr((Expr)`<UUID ref>`)])
      ];
  }
  else {
    stats = [
      // first delete *any* old one, if any
      delete(fkTbl, [where([equ(column(fkTbl, parentFk), SQLExpr::placeholder(name=param))])]),
      // then insert it
      \insert(fkTbl, [parentFk, kidFk], [Value::placeholder(name=param),  evalExpr((Expr)`<UUID ref>`)])
    ];
  }
	          
  return [step(dbName, sql(executeStatement(dbName, pp(stat))), (param: toBeUpdated)) | SQLStat stat <- stats ];
}

list[Step] updateMongoParentManyKids(str dbName, str ent, str fromRole, str to, str toRole, Cardinality toCard, {UUID ","}+ refs, str param, Field toBeUpdated) {
  DBObject q = object([<"_id", DBObject::placeholder(name=param)>]); // unfortunately we cannot reuse expr2obj here...
  
  DBObject makeKid(UUID ref) = \value("<ref>"[1..]);
  
  DBObject u = object([<"$set", object([<fromRole, array([ makeKid(ref) | UUID ref <- refs ])>])>]);
  
  return [step(dbName, mongo(findAndUpdateOne(dbName, parent, pp(q), pp(u))), (param: toBeUpdated))];
}

list[Step] updateMongoParent(str dbName, str ent, str fromRole, str to, str toRole, Cardinality toCard, UUID ref, str param, Field toBeUpdated) { 
  DBObject q = object([<"_id", DBObject::placeholder(name=param)>]); // unfortunately we cannot reuse expr2obj here...
  DBObject kid = \value("<ref>"[1..]);
  DBObject u = object([<"$set", object([<fromRole, kid>])>]);
  if (toCard in {one_many(), zero_many()}) {
    u = object([<"$addToSet", object([<fromRole, kid>])>]);
  }
  return [step(dbName, mongo(findAndUpdateOne(dbName, parent, pp(q), pp(u))), (param: toBeUpdated))];
}


list[Step] breakCrossLinkInSQL(str dbName, str parent, SQLExpr kid, str param, Field kidField, str fromRole, str to, str toRole) {
  SQLStat parentStat = 
    \delete(junctionTableName(parent, fromRole, to, toRole),[
      where([
        equ(column(junctionTableName(parent, fromRole, to, toRole), junctionFkName(to, toRole)), kid)
      ])]);
   return [step(dbName, sql(executeStatement(dbName, pp(parentStat))), (param: kidField))];         
}

list[Step] breakCrossLinkInMongo(str dbName, str parent, DBObject kid, str kidParam, Field kidField, str fromRole, str to, str toRole) {
  // findAndUpdateOne({}, {$pull: {fromRole: <kidParam>}});
  DBObject q = object([]);
  DBObject u = object([<"$pull", object([<fromRole, kid>])>]);
  return [step(dbName, mongo(findAndUpdateOne(dbName, parent, pp(q), pp(u))), (kidParam: kidField))];
}


list[Step] createCrossLinkInSQL(str dbName, str parent, str uuid, str fromRole, str to, str toRole) {
  SQLStat parentStat = 
    \insert(junctionTableName(parent, fromRole, to, toRole)
            , [junctionFkName(to, toRole), junctionFkName(parent, fromRole)]
            , [text(uuid), Value::placeholder(name=ID_PARAM)]);
   return [step(dbName, sql(executeStatement(dbName, pp(parentStat))), (ID_PARAM: generatedIdField()))];         
}


list[Step] createCrossLinkInMongo(str dbName, str parent, str uuid, str fromRole, Cardinality toCard) {
  DBObject q = object([<"_id", \value(uuid)>]);
  DBObject u = object([<"$set", object([<fromRole, DBObject::placeholder(name=ID_PARAM)>])>]);
  if (toCard in {one_many(), zero_many()}) {
    u = object([<"$addToSet", object([<fromRole, DBObject::placeholder(name=ID_PARAM)>])>]);
  }
  return [step(dbName, mongo(findAndUpdateOne(dbName, parent, pp(q), pp(u))), (ID_PARAM: generatedIdField()))];
}

list[Step] compileQuery(r:(Request)`<Query q>`, p:<sql(), str dbName>, Schema s) {
  r = expandNavigation(addWhereIfAbsent(r), s);
  <sqlStat, params> = compile2sql(r, s, p);
  return [step(dbName, sql(executeQuery(dbName, pp(sqlStat))), params)];
}

list[Step] compileQuery(r:(Request)`<Query q>`, p:<mongodb(), str dbName>, Schema s) {
  <methods, params> = compile2mongo(r, s, p);
  for (str coll <- methods) {
    // TODO: signal if multiple!
    return [step(dbName, mongo(find(dbName, pp(methods[coll].query), pp(methods[coll].projection))), params)];
  }
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
  
  smokeIt((Request)`insert Person {name: "Pablo", age: 23}`);
  smokeIt((Request)`insert Person {name: "Pablo", age: 23, reviews: #abc, reviews: #cdef}`);

  smokeIt((Request)`insert Review {text: "Bad"}`);

  
  smokeIt((Request)`insert Review {text: "Bad"} into #pablo.reviews`);
  
  smokeIt((Request)`insert Comment {contents: "Bad"} into #somereview.comment`);


  smokeIt((Request)`delete Review r`);

  
  smokeIt((Request)`delete Review r where r.text == "Bad"`);
  
  smokeIt((Request)`delete Comment c where c.contents == "Bad"`);
  
  smokeIt((Request)`delete Person p`);

  smokeIt((Request)`delete Person p where p.name == "Pablo"`);
  
  smokeIt((Request)`update Person p set {name: "Pablo"}`);

  smokeIt((Request)`update Person p set {name: "Pablo", age: 23}`);


  smokeIt((Request)`update Person p where p.name == "Pablo" set {reviews +: [#abc, #cde]}`);

  smokeIt((Request)`update Person p where p.name == "Pablo" set {reviews +: [#abc, #cde]}`);

  smokeIt((Request)`update Person p where p.name == "Pablo" set {reviews: [#abc, #cde]}`);

  smokeIt((Request)`update Review r set {text: "bad"}`);

  smokeIt((Request)`update Review r where r.text == "Good" set {text: "Bad"}`);

  smokeIt((Request)`update Person p set {name: "Pablo", cash: [#abc, #cde]}`);

  smokeIt((Request)`update Person p set {name: "Pablo", cash +: [#abc, #cde]}`);

  smokeIt((Request)`update Person p set {name: "Pablo", cash -: [#abc, #cde]}`);

}  
