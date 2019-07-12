module lang::typhonql::Type

extend lang::std::Id;

syntax EId = Id \ Primitives;
  
keyword Primitives
  = "int" | "str" | "bool" | "text" | "float" | "blob" | "freetext" ;
   
syntax Type
  = "int"
  | "str"
  | "bool"
  | "text"
  | "float"
  | "blob"
  | "freetext" "[" {Id ","}* nlpfeatures "]"
  | "image" "[" { Id ","}* metadata "]" 
  ;