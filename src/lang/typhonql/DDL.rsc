module lang::typhonql::DDL

extend lang::std::Layout;
extend lang::std::Id;
extend lang::std::Type;


syntax Statement
  = "create" EId entity "{" Feature* features "}"
  | "create" EId entity "." Feature feature 
  | "drop" EId entity
  | "drop" EId entity "." EId feature
  | "rename" EId entity "to" Id name
  | "rename" EId entity "." Id feature "to" Id name
  ;

syntax Feature
  = Id name ":" Type type
  | Id name Ref ref Cardinality cardinality EId target Opposite? oppositeOpt
  ;

syntax DBKind
  = "relational"
  | "document"
  | "graph"
  ;
  
syntax Opposite = "(" EId target "." Id feature ")";  
  
syntax Cardinality
  = \one: 
  | zeroOne: "?"
  | zeroMany: "*"
  | oneMany: "+"
  ;  
  
syntax Ref
  = containment: "=\>"
  | reference: "-\>"
  ;
  

