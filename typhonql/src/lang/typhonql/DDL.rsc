module lang::typhonql::DDL

extend lang::typhonql::Expr;

syntax Statement
  = \createEntity: "create" EId eId "at" Id db
  | \createAttribute: "create" EId eId "." Id name ":" Type typ
  | \createRelation: "create" EId eId "." Id relation Inverse? inverse Arrow EId target "[" CardinalityEnd lower ".." CardinalityEnd upper "]"
  | \dropEntity: "drop" EId eId
  | \dropAttribute: "drop" "attribute" EId eId "." Id name
  | \dropRelation: "drop" "relation" EId eId "." Id name
  | \renameEntity: "rename" EId eId "to" EId newEntityName
  | \renameAttribute: "rename" "attribute" EId eId "." Id name"to" Id newName  
  | \renameRelation: "rename" "relation" EId eId  "." Id name "to" Id newName  
  ;
  
syntax Inverse = inverseId: "(" Id inverse ")";

syntax Type
  = intType: "int" // the 32bit int
  | bigIntType: "bigint"  // 64bit
  | stringType: "string" "(" Nat maxSize ")"
  | textType: "text"
  | pointType: "point" // To check
  | polygonType: "polygon" // To check 
  | boolType: "bool" 
  | floatType: "float" // IEEE float 
  | blobType: "blob" 
  | freeTextType: "freetext" "[" {Id ","}+ nlpFeatures "]"
  | dateType: "date" 
  | dateTimeType: "datetime"
  ;

lexical Nat = [0-9]+ !>> [0-9];

lexical Arrow = "-\>" | ":-\>";

lexical CardinalityEnd = [0-1] | "*";
  
bool isDDL(Statement s) = s is \createEntity || s is \createAttribute || s is \createRelation
  || s is \dropEntity || s is \dropAttribute || s is \dropRelation || s is \renameAttribute || s is \renameRelation; 
