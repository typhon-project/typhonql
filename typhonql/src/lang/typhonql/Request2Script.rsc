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


Script request2script(Request r, Schema s) {
  switch (r) {
  
    case (Request)`<Query q>`: {
      list[Place] order = orderPlaces(r, s);
      return script([ *compile(restrict(r, p, order, s), p, s) | Place p <- order]); 
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
      if (<str parent, _, str fromRole, str toRole, Cardinality toCard, str to, _> <- s.rels, fromRole == "<field>", to == "<e>") {
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
  
  
}  
