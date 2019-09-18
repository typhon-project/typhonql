module lang::typhonql::TDBC

extend lang::typhonql::Query;
extend lang::typhonql::DML;

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
 
