module lang::typhonql::DML

extend lang::typhonql::Expr;
extend lang::typhonql::Query;


syntax Statement
  = "insert" {Obj ","}* objs
  | "delete" Query query
  | "update" EId entity Where? where "set"  "{" {KeyVal ","}* keyVals "}" 
  ;
  

