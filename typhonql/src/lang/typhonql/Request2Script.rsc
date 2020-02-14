module lang::typhonql::Request2Script


import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::Script;
import lang::typhonql::TDBC;
import lang::typhonql::Order;
import lang::typhonql::Normalize;

import lang::typhonql::relational::SQL;
import lang::typhonql::relational::SQL2Text;
import lang::typhonql::relational::Query2SQL;
import lang::typhonql::relational::Insert2SQL;

import lang::typhonql::mongodb::Query2Mongo;
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
          ;
        }
      }
    }
  
<<<<<<< Updated upstream
    case (Request)`insert <EId e> { <{KeyVal ","}* kvs> } into <UUID owner>.<Id field>`: {
      Place p = placeOf("<e>", s);
      if (<str parent, _, str fromRole, str toRole, _, str to, _> <- s.rels, fromRole == "<field>", to == "<e>") {
        Place pp = placeOf("<e>", s);
        switch (<pp, p>) {
            case <<sql(), str dbName>, <sql(), dbName>>: {
               str fk = fkName(parent, to, toRole == "" ? fromRole : toRole);
 			   <stats, params> = insert2sql((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, s, p, parent = <fk, "<owner>">);
 			   return script([step(dbName, sql(executeStatement(dbName, pp(stat))), params) | SQLStat stat <- stats ]);
            }

            case <<sql(), str dbParent>, <sql(), str dbKid>>: {
              SQLStat parentStat = 
                \insert(junctionTableName(parent, fromRole, to, toRole)
                        , [junctionFkName(to, toRole), junctionFkName(parent, fromRole)]
                        , [text(uuid), Value::placeholder(name=ID_PARAM)]);
              <stats, params> = insert2sql((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, s, p);
              return script([step(dbParent, sql(executeStatement(dbParent, pp(parentStat)), params))]
                + [ step(dbKid, sql(executeStatement(dbKid, pp(stat))), params) | SQLStat stat <- stats ]);
			}

            case <<sql(), str dbParent>, <mongodb(), str dbKid>>: {
			   SQLStat parentStat = 
                \insert(junctionTableName(parent, fromRole, to, toRole)
                        , [junctionFkName(to, toRole), junctionFkName(parent, fromRole)]
                        , [text(uuid), Value::placeholder(name=ID_PARAM)]);
                        
              return script([step(dbParent, sql(executeStatement(dbParent, pp(parentStat)), params))]
                + [ /* todo */ ]);          
			  // insert new object in mongo 
			  
			}
            
            case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
              ;
            }
            
            case <<mongodb(), str dbParent>, <mongodb(), str dbKid>>: {
              ;
            }

            case <<mongodb(), str dbParent>, <sql(), str dbKid>>: {
              ;
            }
        }
      }
      else {
        throw "No owner type found for entity <e> via <field>";
      }
    }
    
    default: 
      throw "Unsupported request: `<r>`";
    
=======
  // TODO change
  for (Place p <- order) {
    Request r = restrict(r, p, order, s);
    println("RESTRICT for <p>: <r>");
    scr.steps += compile(r, p, s);
>>>>>>> Stashed changes
  }
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
    // todo: add projections
    println("COLLECTION: <coll>, <methods[coll]>");
    return [step(dbName, mongo(find(dbName, pp(methods[coll].query), pp(methods[coll].projection))), params)];
  }
}

//list[Step] compile((Request)`insert <EId e> { <{KeyVal ","}* kvs> } into <UUID owner>.<Id field>`, p:<sql(), str dbName>, Schema s) {
//  str fk = fkName(parent, to, toRole == "" ? fromRole : toRole);
//  <stats, params> = insert2sql((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, s, p, parent = <fk, "<owner>">);
//  
//}

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
<<<<<<< Updated upstream

  q = (Request)`from Person p, Review r select r.text, p.name where p.name == "Pablo", p.reviews == r`;  
  iprintln(request2script(q, s));
  
  iprintln(request2script((Request)`insert Person {name: "Pablo", age: 23}`, s));
  iprintln(request2script((Request)`insert Person {name: "Pablo", age: 23, reviews: #abc, reviews: #cdef}`, s));
  
  //iprintln(request2script((Request)`insert Review {text: "Bad"} into #pablo.reviews`));

=======
  
  
  q = (Request)`from User u, Review r select r where r.user == u, u.name == "Pablo"`;
  iprintln(request2script(q, s));
  
  
>>>>>>> Stashed changes
}  
