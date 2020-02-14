module lang::typhonql::DML

extend lang::typhonql::Expr;
extend lang::typhonql::Query;


syntax Statement
  = \insert: "insert" {Obj ","}* objs
  | insertInto: "insert" Obj obj "into" Expr parent "." Id field
  | delete: "delete" Binding binding Where? where
  | update: "update" Binding binding Where? where "set"  "{" {KeyVal ","}* keyVals "}" 
  ;
  
syntax PreparedStatement
  = \insert: "insert" {Obj ","}* objs
  | delete: "delete" Binding binding Where? where
  | update: "update" Binding binding Where? where "set"  "{" {KeyVal ","}* keyVals "}" 
  ;