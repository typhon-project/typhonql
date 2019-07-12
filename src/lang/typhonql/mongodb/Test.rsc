module lang::typhonql::mongodb::Test

import lang::typhonql::TDBC;
import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::mongodb::DML2Method;
import lang::typhonql::mongodb::Select2Find;

import IO;


void smokeTestMongo() {
  Schema myDb = myDbSchema();
  
  
  println("\n### Insert with nesting");
  Request ins1 = (Request)`insert Product { name: "TV", review: [ Review {  } ] }`;
  println("# TyphonQL <ins1>");
  
  iprintln(compile2mongo(ins1, myDb));
  
  
  println("\n### Insert with cross reference");
  Request ins3 = (Request) `insert Order { totalAmount: 23, paidWith: cc }, @cc CreditCard { number: "12345678" }`;

  println("# TyphonQL: <ins3>");

  iprintln(compile2mongo(ins3, myDb));

  
  println("\n### Select");
  Request q1 = (Request) `from Order o select o.totalAmount where o.users.name == "alice"`;

  println("# TyphonQL: <q1>");

  iprintln(compile2mongo(q1, myDb));
  

  println("\n### Select");
  Request q2 = (Request) `from Product p select p.review where p.name == "TV"`;

  println("# TyphonQL: <q2>");

  iprintln(compile2mongo(q2, myDb));
  
  

 }