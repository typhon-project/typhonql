module lang::typhonql::mongodb::Test

import lang::typhonql::DML;
import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::mongodb::DML2Method;
import lang::typhonql::mongodb::Select2Find;

import IO;


void smokeTestMongo() {
  Schema myDb = myDbSchema();
  
  
  println("\n### Insert with nesting");
  Statement ins1 = (Statement)`insert Product { name: "TV", review: [ Review {  } ] }`;
  println("# TyphonQL <ins1>");
  
  iprintln(dml2mongo(ins1, myDb));
  
  
  println("\n### Insert with cross reference");
  Statement ins3 = (Statement) `insert Order { totalAmount: 23, paidWith: cc }, @cc CreditCard { number: "12345678" }`;

  println("# TyphonQL: <ins3>");

  iprintln(dml2mongo(ins3, myDb));

  
  println("\n### Select");
  Query q1 = (Query) `from Order o select o.totalAmount where o.users.name == "alice"`;

  println("# TyphonQL: <q1>");

  iprintln(select2find(q1, myDb));
  

  println("\n### Select");
  Query q2 = (Query) `from Product p select p.review where p.name == "TV"`;

  println("# TyphonQL: <q2>");

  iprintln(select2find(q2, myDb));
  
  

  //Statement stat;
  //
  //println("\n#### Update ");
  //stat = (Statement)`update User u where u.name == "alice" set { name: "bob"}`;
  //println("TyphonQL: <stat>");
  //println(pp(dml2sql(stat, myDb)));
  //
  //println("\n#### Delete ");
  //stat = (Statement)`delete User u where u.name == "alice"`;
  //println("TyphonQL: <stat>");
  //println(pp(dml2sql(stat, myDb)));
 }