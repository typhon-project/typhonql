module lang::typhonql::TDBC

extend lang::typhonql::Query;
extend lang::typhonql::DDL;
extend lang::typhonql::DML;

start syntax Request
  = Query
  | Statement
  | "{" Statement* "}"
  ;

syntax Expr 
  = "?"
  | "?" VId
  ;
 
