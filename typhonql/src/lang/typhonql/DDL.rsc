module lang::typhonql::DDL

extend lang::typhonql::Expr;

syntax Statement
  = \createEntity: "create" EId eId "at" Id db
  | \createAttribute: "create" EId eId "." Id name ":" Type typ
  | \createRelation: "create" EId eId "." Id relation Inverse? inverse Arrow EId target "[" CardinalityEnd lower ".." CardinalityEnd upper "]"
  | \dropEntity: "drop" EId eId
  | \dropAttribute: "drop" "attribute" EId eId "." Id name
  | \dropRelation: "drop" "relation" EId eId "." Id name
  | \renameAttribute: "rename attribute" EId eId "." Id name"to" Id newName  
  | \renameRelation: "rename relation" EId eId  "." Id name "to" Id newName  
  ;
  
syntax Inverse = "(" Id inverse ")";

lexical Type
  = "int" | "str" | "bool" | "text" | "float" | "blob" | "freetext" ;

lexical Arrow = "-\>" | ":-\>";

lexical CardinalityEnd = [0-1] | "*";