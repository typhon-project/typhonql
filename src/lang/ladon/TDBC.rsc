module lang::ladon::TDBC

extend lang::ladon::Query;
extend lang::ladon::DDL;
extend lang::ladon::DML;

start syntax Request
  = Query
  | Statement
  | "{" Statement* "}"
  ;

syntax Expr 
  = "?"
  | "?" VId
  ;
 
