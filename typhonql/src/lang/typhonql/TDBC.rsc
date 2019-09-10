module lang::typhonql::TDBC

extend lang::typhonql::Query;
extend lang::typhonql::DML;

start syntax Script
  = "#" ProjectLoc model Scratch scratch;


lexical ProjectLoc
  = @category="Constant" [a-zA-Z_\-.0-9/:@]+ !>> [a-zA-Z_\-.0-9/:@];
   

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
 
