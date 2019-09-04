module lang::typhonql::attic::Compiler

import lang::typhonql::TDBC;
import lang::typhonql::Partition;
import lang::typhonql::relational::Compiler;
import lang::typhonql::relational::SQL;
import lang::typhonql::relational::SQL2Text;

import lang::typhonql::mongodb::Compiler;
import lang::typhonql::mongodb::DBCollection;

import lang::typhonml::TyphonML;
import lang::typhonml::Util;

import IO;


/*

Global assumptions of the compiler/partitioner

- Cross ownership is possible, but no cascade delete semantics is realized 
  because this requires full recursion over the partitioning and select/delete cycle.
  Ownership local to database (sql/mongo) is dealt with the respective native m
  mechanisms (cascade delete in SQL, and nesting in MongoDB).
  


*/


lrel[Place, value] compile(Request request, Schema schema) {
  lrel[Place, Request] script = partition(request, schema);
  return [ *compile(p, r, schema) | <Place p, Request r> <- script ];
}

lrel[Place, value] compile(p:<mongodb(), _>, Request r, Schema s) 
  = [ <p, compile2mongo(r, s)> ];


lrel[Place, value] compile(p:<sql(), _>, Request r, Schema s) 
  = [ <p, pp(stat)> | SQLStat stat <- compile2sql(r, s) ];

lrel[Place, value] compile(p:<recombine(), _>, Request r, Schema s) 
  = [ <p, s> | Stm s <- compile2java(r, s) ];



default lrel[Place, value] compile(Place p, Request _, Schema _) {
  throw "Unsupported DB type <p.db>";
}

void printScript(Request req, lrel[Place, value] script) {
  println("REQUEST: <req>");
  println("<for (<Place p, value v> <- script) {>
          '  <p>: <v>
          '<}>");  
  
}

void testRequest(Request r, Schema s) {
  script = compile(r, s);
  printScript(r, script);
}

void smokeTestCompiler() {
  Schema s = myDbSchema();
  
  testRequest((Request)`insert Product { name: "TV", review: Review {  } }`, s);
  testRequest((Request)`insert @tv Product { name: "TV"}, Review { product: tv }`, s);
  testRequest((Request)`insert @tv Product { name: "TV"}, Product {name: "Bla" }, Review { product: tv }`, s);
  testRequest((Request)`insert Order { totalAmount: 23, paidWith: cc }, @cc CreditCard { number: "12345678" }`, s);
  testRequest((Request)`insert Order { users: alice }, @alice User { name: "alice" }`, s);
  testRequest((Request)`insert Order { users: [ User { name: "alice" } ]}`, s);
  testRequest((Request)`insert Order { users: [ User { name: "alice" }, User { name: "bob" } ]}`, s);

  testRequest((Request)`from Order o select o.totalAmount where o.users.name == "alice"`, s);
  testRequest((Request)`from Product p select p`, s);
  testRequest((Request)`from Product p select p.name where p.description != ""`, s);
  testRequest((Request)`from Product p select p.name where p.description != "", p.review.id != ""`, s);
  
  testRequest((Request)`from Product p select p.review where p.name != "", p.review.id != ""`, s);
  
  
  
  testRequest((Request)`update Product p where p.name == "TV" set {name: "Hallo"}`, s);

  testRequest((Request)`update User u where u.name == "alice" set { name: "bob"}`, s);
  testRequest((Request)`delete User u where u.name == "alice"`, s);
  testRequest((Request)`delete Product p where p.name != "", p.review.id != ""`, s);
  
}