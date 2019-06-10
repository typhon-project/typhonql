module lang::typhonql::DML

extend lang::typhonql::Expr;
extend lang::typhonql::Query;

/*
update from Person p select p where p.age >= 18 set it@Person {name : "x", spouse: it}
*/

syntax Statement
  = "insert" {Obj ","}* objs
  | "delete" Query query
  | "update" Query query "set" {Obj ","}* objs
  ;
  

