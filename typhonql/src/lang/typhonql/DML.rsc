module lang::typhonql::DML

extend lang::typhonql::Expr;
extend lang::typhonql::Query;


syntax Statement
  = \insert: "insert" Obj
  | delete: "delete" Binding binding Where? where
  | update: "update" Binding binding Where? where "set" Updates 
  ;
  
  
  
syntax Obj
  = EId entity "{" {Prop ","}* "}"
  ;
  
syntax Prop
  = Id field ":" {Expr ","}+ values 
  | "@id" ":" Expr value // uuid or placeholder
  ; 
   
  
syntax Update
  = Id field ":" {Expr ","}+ values // prims, custom, or uuid or null
  | Id field ":" "+" {Expr ","}+ refs  // only uuid
  | Id field ":" "-" {Expr ","}+ refs  // only uuid
  ;
  
syntax PreparedStatement
  = \insert: "insert" {Obj ","}* objs
  | delete: "delete" Binding binding Where? where
  | update: "update" Binding binding Where? where "set"  "{" {KeyVal ","}* keyVals "}" 
  ;
