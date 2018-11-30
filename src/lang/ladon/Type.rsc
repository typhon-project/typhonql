module lang::ladon::Type

extend lang::std::Id;

syntax EId = Id \ Primitives;
  
keyword Primitves
  = "int" | "str" | "bool" | "text" | "freetext" | "float" | "blob";
   
syntax Type
  = "int"
  | "str"
  | "bool"
  | "text"
  | "freetext" // todo annos
  | "float"
  | "blob"
  ;
  