module lang::typhonql::relational::Test


import lang::typhonql::relational::SchemaToSQL;
import lang::typhonql::relational::DML2SQL;
import lang::typhonql::relational::Select2SQL;
import lang::typhonql::relational::SQL;
import lang::typhonql::relational::SQL2Text;
import lang::typhonql::DML;
import lang::typhonml::Util;
import lang::typhonml::TyphonML;

import IO;


test bool containmentBecomesFk()
  = schema2sql(schema({<"Computer", \one(), "has", "has^", \one(), "Screen", true>}, {}))
  == [
  create(
    "Computer",
    [column(
        "Computer.@id",
        char(36),
        [
          notNull(),
          unique()
        ])],
    [primaryKey("Computer.@id")]),
  create(
    "Screen",
    [column(
        "Computer.Screen.has^",
        char(36),
        [
          unique(),
          notNull()
        ])],
    []),
  alterTable(
    "Screen",
    [addConstraint(foreignKey(
          "Computer.Screen.has^",
          "Computer",
          "Computer.@id",
          cascade()))])
];




void smokeTest() {
  Schema myDb = myDbSchema();
  
  println("### SQL Schema for MyDb\n");
  println(pp(schema2sql(myDb)));
  
  println("\n### Insert with nesting");
  Statement ins1 = (Statement)`insert Product { name: "TV", review: Review {  } }`;
  println("# TyphonQL <ins1>");
  
  println(pp(insert2sql(ins1, myDb)));
  
  
  println("\n### Insert without nesting but containment via opposite");
  Statement ins2 = (Statement) `insert @tv Product { name: "TV"}, Review { product: tv }`;
  println("# TyphonQL: <ins2>");

  println(pp(insert2sql(ins2, myDb)));
  
  println("\n### Insert with cross reference");
  Statement ins3 = (Statement) `insert Order { totalAmount: 23, paidWith: cc }, @cc CreditCard { number: "assa" }`;

  println("# TyphonQL: <ins3>");

  println(pp(insert2sql(ins3, myDb)));

  println("\n### Insert with cross reference via opposite");
  Statement ins4 = (Statement) `insert Order { users: alice }, @alice User { name: "alice" }`;

  println("# TyphonQL: <ins4>");

  println(pp(insert2sql(ins4, myDb)));

  println("\n### Insert with cross reference via nesting");
  Statement ins5 = (Statement) `insert Order { users: [ User { name: "alice" } ]}`;

  println("# TyphonQL: <ins5>");

  println(pp(insert2sql(ins5, myDb)));
  
  
  println("\n### Joining select via junction table");
  Query q1 = (Query) `from Order o select o.totalAmount where o.users.name == "alice"`;

  println("# TyphonQL: <q1>");

  println(pp(select2sql(q1, myDb)));

}


