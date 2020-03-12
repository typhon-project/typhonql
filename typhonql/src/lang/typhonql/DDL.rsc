module lang::typhonql::DDL

extend lang::typhonql::Expr;

syntax Statement
  = \createEntity: "create" EId eId "at" Id db
  | \createAttribute: "create" EId eId "." Id name ":" Type typ
  | \createRelation: "create" EId eId "." Id relation Inverse? inverse Arrow EId target "[" CardinalityEnd lower ".." CardinalityEnd upper "]"
  | \dropEntity: "drop" EId eId
  | \dropAttribute: "drop" "attribute" EId eId "." Id name
  | \dropRelation: "drop" "relation" EId eId "." Id name
  | \renameAttribute: "rename" "attribute" EId eId "." Id name"to" Id newName  
  | \renameRelation: "rename" "relation" EId eId  "." Id name "to" Id newName  
  ;
  
syntax Inverse = inverseId: "(" Id inverse ")";

syntax Type
  = "int" // the 32bit int
  | "bigint"  // 64bit
  | "string" "(" Nat maxSize ")"
  | "text"
  | "point" // To check
  | "polygon" // To check 
  | "bool" 
  | "float" // IEEE float 
  | "blob" 
  | "freetext" "[" {Id ","}+ nlpFeature "]"
  | "date" 
  | "datetime"
  ;

lexical Nat = [0-9]+ !>> [0-9];

syntax Arrow = "-\>" | ":-\>";

lexical CardinalityEnd = [0-1] | "*";
  
bool isDDL(Statement s) = s is \createEntity || s is \createAttribute || s is \createRelation
  || s is \dropEntity || s is \dropAttribute || s is \dropRelation || s is \renameAttribute || s is \renameRelation; 
