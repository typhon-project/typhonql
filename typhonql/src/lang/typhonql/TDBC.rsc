module lang::typhonql::TDBC

extend lang::typhonql::Query;
extend lang::typhonql::DML;
extend lang::typhonql::DDL;

start syntax Script
  = Scratch scratch;

start syntax Scratch
  = Request* requests
  ;

start syntax Request
  = query: Query
  | statement: Statement
  ;

syntax Expr 
  = "?"
  | "?" VId
  ;
 
