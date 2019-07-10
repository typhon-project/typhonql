module lang::typhonql::TDBC

extend lang::typhonql::Query;
extend lang::typhonql::DDL;
extend lang::typhonql::DML;

start syntax Scratch
  = Request*
  ;

start syntax Request
  = Query
  | Statement
  ;

syntax Expr 
  = "?"
  | "?" VId
  ;
 
