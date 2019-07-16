module lang::typhonql::relational::Test


import lang::typhonql::relational::SchemaToSQL;
import lang::typhonql::relational::DML2SQL;
import lang::typhonql::relational::Select2SQL;
import lang::typhonql::relational::SQL;
import lang::typhonql::relational::SQL2Text;
import lang::typhonql::TDBC;
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
  
  return;
  println("\n### Insert with nesting");
  Request ins1 = (Request)`insert Product { name: "TV", review: Review {  } }`;
  println("# TyphonQL <ins1>");
  
  println(pp(insert2sql(ins1, myDb)));
  
  
  println("\n### Insert without nesting but containment via opposite");
  Request ins2 = (Request) `insert @tv Product { name: "TV"}, Review { product: tv }`;
  println("# TyphonQL: <ins2>");

  println(pp(insert2sql(ins2, myDb)));
  
  println("\n### Insert with cross reference");
  Request ins3 = (Request) `insert Order { totalAmount: 23, paidWith: cc }, @cc CreditCard { number: "12345678" }`;

  println("# TyphonQL: <ins3>");

  println(pp(insert2sql(ins3, myDb)));

  println("\n### Insert with cross reference via opposite");
  Request ins4 = (Request) `insert Order { users: alice }, @alice User { name: "alice" }`;

  println("# TyphonQL: <ins4>");

  println(pp(insert2sql(ins4, myDb)));

  println("\n### Insert with cross reference via nesting");
  Request ins5 = (Request) `insert Order { users: [ User { name: "alice" } ]}`;

  println("# TyphonQL: <ins5>");

  println(pp(insert2sql(ins5, myDb)));

  println("\n### Insert with cross reference via nesting list flattening");
  Request ins6 = (Request) `insert Order { users: [ User { name: "alice" }, User { name: "bob" } ]}`;

  println("# TyphonQL: <ins6>");

  println(pp(insert2sql(ins6, myDb)));
  
  
  println("\n### Joining select via junction table");
  Query q1 = (Query) `from Order o select o.totalAmount where o.users.name == "alice"`;

  println("# TyphonQL: <q1>");

  println(pp(select2sql(q1, myDb)));
  

  println("\n### Select retrieves contained entities");
  Query q2 = (Query) `from Product p select p`;

  println("# TyphonQL: <q2>");

  println(pp(select2sql(q2, myDb)));

  println("\n### Basic query");
  Query q3 = (Query) `from Product p select p.name where p.description != ""`;

  println("# TyphonQL: <q3>");

  println(pp(select2sql(q3, myDb)));

  
  Request stat;
  
  println("\n#### Update ");
  stat = (Request)`update User u where u.name == "alice" set { name: "bob"}`;
  println("TyphonQL: <stat>");
  println(pp(compile2sql(stat, myDb)));
  
  println("\n#### Delete ");
  stat = (Request)`delete User u where u.name == "alice"`;
  println("TyphonQL: <stat>");
  println(pp(compile2sql(stat, myDb)));
  

}


