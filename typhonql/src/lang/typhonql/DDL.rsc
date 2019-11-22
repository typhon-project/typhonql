module lang::typhonql::DDL

extend lang::typhonql::Expr;

syntax Statement
  = \createEntity: "create" EId eId "at" Id db
  | \createAttribute: "create" EId eId "." Id name ":" Type typ
  | \createRelation: "create" EId eId "." Id relation Arrow EId target "[" Cardinality fromCard ".." Cardinality toCard "]"
  | \dropEntity: "drop" EId eId
  | \dropAttribute: "drop" "attribute" EId eId "." Id name
  | \dropRelation: "drop" "relation" EId eId "." Id name
  ;
  

lexical Type
  = "int" | "str" | "bool" | "text" | "float" | "blob" | "freetext" ;

lexical Arrow = "-\>" | ":-\>";

lexical Cardinality = [0-1] | "*";