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
      return script([ *compile(restrict(r, p, order, s), p, s) | Place p <- order]); 
    }
    
    case (Request)`delete <EId e> <VId x>`: {
      return request2script((Request)`delete <EId e> <VId x> where true`, s);
    }
    
    case (Request)`delete <EId e> <VId x> where <{Expr ","}+ ws>`: {
      str ent = "<e>";
      Place p = placeOf(ent, s);
      
      list[Step] steps = [];
      
      // first, find all id's of e things that need to be deleted
      // including the kid id's of all non-locally owned entities
      // NB: since we're only deleted a single entity type, partitioning has no effect
      // on this query, and we get a single "param" corresponding to p.name
      list[str] results = ["<x>.@id"]
        + [ "<x>.<f>" | <ent, _, str f, _, _, str to, true> <- s.rels, placeOf(to, s) != p ];

      Request req = [Request]"from <e> <x> select <intercalate(", ", results)> where <ws>";
      println("------\> REQUEST = <req>");

      Script scr = script(compile(req, p, s));
       
      println("RESULT = <scr>");
      
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
              scr.steps += unlinkSQLParent(dbParent, parent, "TO_DELETE", fieldToBeDeleted, fromRole, ent, toRole); 
			}

            case <<sql(), str dbParent>, <mongodb(), str dbKid>>: {
              scr.steps += unlinkSQLParent(dbParent, parent, "TO_DELETE", fieldToBeDeleted, fromRole, ent, toRole); 
			}
            
            case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
              scr.steps += unlinkMongoParent(dbName, parent, "TO_DELETE", fieldToBeDeleted, fromRole, ent, toRole);
            }
            
            case <<mongodb(), str dbParent>, <mongodb(), str dbKid>>: {
              scr.steps += unlinkMongoParent(dbParent, parent, "TO_DELETE", fieldToBeDeleted, fromRole, ent, toRole);
            }

            case <<mongodb(), str dbParent>, <sql(), str dbKid>>: {
              scr.steps += unlinkMongoParent(dbParent, parent, "TO_DELETE", fieldToBeDeleted, fromRole, ent, toRole);
            }
        }
      }
      
      // then we (cascade) delete kids that are not automatic (e.g. cross db).
      
      for (<ent, _, str fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels, placeOf(to, s) != p) {
        Place kidPlace = placeOf(to, s);
         //set[Field] externalKidFieldsToBeDeleted = 
         // [ <p.name, "<x>", to, f> |  <ent, _, str f, _, _, str to, true> <- s.rels, placeOf(to, s) != p ];
        
        switch (<p, kidPlace>) {
            case <<sql(), str dbName>, <sql(), dbName>>: {
              ; // nothing to be done, kids will be deleted as a result of cascade delete
            }

            case <<sql(), str dbName>, <sql(), str dbKid>>: {
              // NB this could be done based on the id of the entity to be deleted itself
              // but unlinkSQLParent now deletes based on the kid's id
              scr.steps += unlinkSQLParent(dbName, ent, "TO_DELETE", <p.name, "<x>", to, fromRole>, fromRole, to, toRole);
              SQLStat stat = delete(tableName(to), [
               where([equ(column(tableName(to), typhonId(to)), SQLExpr::placeholder(name="TO_DELETE"))])]);
            
              scr.steps += [step(dbKid, sql(executeStatement(dbKid, pp(stat))), ("TO_DELETE": <p.name, "<x>", to, fromRole>))]; 
			}

            case <<sql(), str dbName>, <mongodb(), str dbKid>>: {
              // on dbName delete from junction table
              scr.steps += unlinkSQLParent(dbName, ent, "TO_DELETE", <p.name, "<x>", to, fromRole>, fromRole, to, toRole);
              
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
            
          scr.steps += [step(dbName, sql(executeStatement(dbName, pp(stat))), ("TO_DELETE": <p.name, "<x>", ent, "@id">))];  
        }
        
        case <mongodb(), str dbName>: {
          DBObject q = object([<"_id", DBObject::placeholder(name="TO_DELETE")>]);
          scr.steps += [step(dbName, mongo(deleteOne(dbName, ent, pp(q))),  ("TO_DELETE": <p.name, "<x>", ent, "@id">))];
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
              return script(linkSQLParent(dbParent, parent, uuid, fromRole, to, toRole)
                + [ step(dbKid, sql(executeStatement(dbKid, pp(stat))), params) | SQLStat stat <- stats ]);
			}

            case <<sql(), str dbParent>, <mongodb(), str dbKid>>: {
              return script(linkSQLParent(dbParent, parent, uuid, fromRole, to, toRole)
                + insert2mongo((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, s, p));          
			  
			}
            
            case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
              return script(linkMongoParent(dbName, parent, uuid, fromRole, toCard)
                 + insert2mongo((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, s, p));
            }
            
            case <<mongodb(), str dbParent>, <mongodb(), str dbKid>>: {
              return script(linkMongoParent(dbParent, parent, uuid, fromRole, toCard) 
                + insert2mongo((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, s, p));
            }

            case <<mongodb(), str dbParent>, <sql(), str dbKid>>: {
              <stats, params> = insert2sql((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, s, p);
              return script(linkMongoParent(dbParent, parent, uuid, fromRole, toCard) 
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


list[Step] unlinkSQLParent(str dbName, str parent, str kidParam, Field kidField, str fromRole, str to, str toRole) {
  SQLStat parentStat = 
    \delete(junctionTableName(parent, fromRole, to, toRole),[
      where([
        equ(column(junctionTableName(parent, fromRole, to, toRole), junctionFkName(to, toRole)), SQLExpr::placeholder(name=kidParam))
      ])]);
   return [step(dbName, sql(executeStatement(dbName, pp(parentStat))), (kidParam: kidField))];         
}

list[Step] unlinkMongoParent(str dbName, str parent, str kidParam, Field kidField, str fromRole, str to, str toRole) {
  // findAndUpdateOne({}, {$pull: {fromRole: <kidParam>}});
  DBObject q = object([]);
  DBObject u = object([<"$pull", object([<fromRole, DBObject::placeholder(name=kidParam)>])>]);
  return [step(dbName, mongo(findAndUpdateOne(dbName, parent, pp(q), pp(u))), (kidParam: kidField))];
}


list[Step] linkSQLParent(str dbName, str parent, str uuid, str fromRole, str to, str toRole) {
  SQLStat parentStat = 
    \insert(junctionTableName(parent, fromRole, to, toRole)
            , [junctionFkName(to, toRole), junctionFkName(parent, fromRole)]
            , [text(uuid), Value::placeholder(name=ID_PARAM)]);
   return [step(dbName, sql(executeStatement(dbName, pp(parentStat))), (ID_PARAM: generatedIdField()))];         
}

list[Step] linkMongoParent(str dbName, str parent, str uuid, str fromRole, Cardinality toCard) {
  DBObject q = object([<"_id", \value(uuid)>]);
  DBObject u = object([<"$set", object([<fromRole, DBObject::placeholder(name=ID_PARAM)>])>]);
  if (toCard in {one_many(), zero_many()}) {
    u = object([<"$addToSet", object([<fromRole, DBObject::placeholder(name=ID_PARAM)>])>]);
  }
  return [step(dbName, mongo(findAndUpdateOne(dbName, parent, pp(q), pp(u))), (ID_PARAM: generatedIdField()))];
}

list[Step] compile(r:(Request)`<Query q>`, p:<sql(), str dbName>, Schema s) {
  r = expandNavigation(addWhereIfAbsent(r), s);
  <sqlStat, params> = compile2sql(r, s, p);
  return [step(dbName, sql(executeQuery(dbName, pp(sqlStat))), params)];
}

list[Step] compile(r:(Request)`<Query q>`, p:<mongodb(), str dbName>, Schema s) {
  println("r = <r>");
  <methods, params> = compile2mongo(r, s, p);
  for (str coll <- methods) {
    // TODO: signal if multiple!
    println("COLLECTION: <coll>, <methods[coll]>");
    return [step(dbName, mongo(find(dbName, pp(methods[coll].query), pp(methods[coll].projection))), params)];
  }
}

void smokeScript() {
  s = schema({
    <"Person", zero_many(), "reviews", "user", \one(), "Review", true>,
    <"Review", \one(), "user", "reviews", \zero_many(), "Person", false>,
    <"Review", \one(), "comment", "owner", \zero_many(), "Comment", true>,
    <"Comment", zero_many(), "replies", "owner", \zero_many(), "Comment", true>
  }, {
    <"Person", "name", "String">,
    <"Person", "age", "int">,
    <"Review", "text", "String">,
    <"Comment", "contents", "String">,
    <"Reply", "reply", "String">
  },
  placement = {
    <<sql(), "Inventory">, "Person">,
    <<mongodb(), "Reviews">, "Review">,
    <<mongodb(), "Reviews">, "Comment">
  } 
  );
  
  Request q = (Request)`from Person p, Review r select r.text, p.name where p.name == "Pablo", p.reviews == r`;  
  iprintln(request2script(q, s));

  q = (Request)`from Person p, Review r select r.text, p.name where p.name == "Pablo", p.reviews == r`;  
  iprintln(request2script(q, s));

  q = (Request)`from Person u, Review r select r where r.user == u, u.name == "Pablo"`;
  iprintln(request2script(q, s));
  
  iprintln(request2script((Request)`insert Person {name: "Pablo", age: 23}`, s));
  iprintln(request2script((Request)`insert Person {name: "Pablo", age: 23, reviews: #abc, reviews: #cdef}`, s));

  iprintln(request2script((Request)`insert Review {text: "Bad"}`, s));

  
  iprintln(request2script((Request)`insert Review {text: "Bad"} into #pablo.reviews`, s));
  
  iprintln(request2script((Request)`insert Comment {contents: "Bad"} into #somereview.comment`, s));


  iprintln(request2script((Request)`delete Review r`, s));

  
  iprintln(request2script((Request)`delete Review r where r.text == "Bad"`, s));
  
  iprintln(request2script((Request)`delete Comment c where c.contents == "Bad"`, s));
  
  iprintln(request2script((Request)`delete Person p`, s));

  iprintln(request2script((Request)`delete Person p where p.name == "Pablo"`, s));

  
}  
