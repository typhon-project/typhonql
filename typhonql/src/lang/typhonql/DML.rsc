module lang::typhonql::DML

extend lang::typhonql::Expr;
extend lang::typhonql::Query;


syntax Statement
  = \insert: "insert" {Obj ","}* objs
  | insertInto: "insert" Obj obj "into" Expr parent "." Id field
  | delete: "delete" Binding binding Where? where
  | update: "update" Binding binding Where? where "set"  "{" {KeyVal ","}* keyVals "}" 
  ;
  
// extension for update: not to be used in insert
syntax KeyVal 
  = add: Id key "+:" Expr value
  | remove: Id key "-:" Expr value
  ;
  
  
syntax PreparedStatement
  = \insert: "insert" {Obj ","}* objs
  | delete: "delete" Binding binding Where? where
  | update: "update" Binding binding Where? where "set"  "{" {KeyVal ","}* keyVals "}" 
  ;