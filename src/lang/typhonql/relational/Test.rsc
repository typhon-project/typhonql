module lang::typhonql::relational::Test


import lang::typhonql::relational::SchemaToSQL;
import lang::typhonql::relational::DML2SQL;
import lang::typhonql::relational::SQL;
import lang::typhonql::relational::SQL2Text;
import lang::typhonql::DML;
import lang::typhonml::Util;

import IO;

void smokeTest() {
  Schema myDb = myDbSchema();
  
  println("### SQL Schema for MyDb\n");
  println(pp(schema2sql(myDb)));
  
  println("\n### Insert with nesting");
  Statement ins1 = (Statement)`insert Product { name: "TV", review: Review {  } }`;
  println("# TyphonQL <ins1>");
  
  println(pp(dml2sql(ins1, myDb)));
  
  
  println("\n### Insert without nesting but containment via opposite");
  Statement ins2 = (Statement) `insert @tv Product { name: "TV"}, Review { product: tv }`;
  println("# TyphonQL: <ins2>");

  println(pp(dml2sql(ins2, myDb)));
  
  println("\n### Insert with cross reference");
  Statement ins3 = (Statement) `insert Order { totalAmount: 23, paidWith: cc }, @cc CreditCard { number: "assa" }`;

  println("# TyphonQL: <ins3>");

  println(pp(dml2sql(ins3, myDb)));

}


