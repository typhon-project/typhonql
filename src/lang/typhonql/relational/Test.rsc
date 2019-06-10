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
  Statement ins2 = (Statement)`insert Product { name: "TV", review: Review {  } }`;
  println("# TyphonQL: <ins2>");

  println(pp(dml2sql(ins2, myDb)));
  
}



/*
Turn this into a test case based on mydb.tml (it shows how nesting or inverse usage
lead to the same SQL):

rascal>ins = (Statement)`insert @tv Product { name: "TV", review: Review {  } }`;
Statement: (Statement) `insert @tv Product { name: "TV", review: Review {  } }`
rascal>println(pp(dml2sql(ins, s)))
OBJ: @obj_0 Review {}
OBJ: @tv Product { name: "TV", review: obj_0 }
insert into `Review_entity` (_typhon_id) values ('f05eeb86-ae87-4cb5-910c-bd27373013de');

insert into `Product_entity` (_typhon_id, name) values ('e2612f93-87e8-4d44-a2d5-0bebded8c6ca', 'TV');

update `Review_entity` set `product_id` = 'e2612f93-87e8-4d44-a2d5-0bebded8c6ca'
where (`Review_entity`.`_typhon_id`) = ('f05eeb86-ae87-4cb5-910c-bd27373013de')
ok
rascal>ins = (Statement)`insert @tv Product { name: "TV"}, Review { product: tv }`;
Statement: (Statement) `insert @tv Product { name: "TV"}, Review { product: tv }`
rascal>println(pp(dml2sql(ins, s)))
OBJ: @obj_0 Review {product: tv}
OBJ: @tv Product { name: "TV"}
insert into `Review_entity` (_typhon_id) values ('b0ce86a7-c2a6-418c-be09-c4f546ce4994');

insert into `Product_entity` (_typhon_id, name) values ('a1e20762-4eee-40d6-99d6-02f359700313', 'TV');

update `Review_entity` set `product_id` = 'a1e20762-4eee-40d6-99d6-02f359700313'
where (`Review_entity`.`_typhon_id`) = ('b0ce86a7-c2a6-418c-be09-c4f546ce4994')

*/

