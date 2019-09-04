module lang::typhonql::Expr

extend lang::std::Layout;
extend lang::std::Id;
extend lang::std::Id;

syntax Expr
  = attr: VId var "." {Id "."}+  attrs
  | var: VId 
  | key: VId "." "@id"
  | @category="Number" \int: Int
  | @category="Constant" \str: Str
  | \bool: Bool
  | uuid: UUID
  | bracket "(" Expr arg ")"
  | obj: Obj // for use in insert and allow nesting of objects
  | lst: "[" {Obj ","}* "]" // NB: only objects! TODO: we might want Object refs as well.
  | null: "null"
  | pos: "+" Expr arg
  | neg: "-" Expr arg
  | call: VId name "(" {Expr ","}* args ")"
  | not: "!" Expr arg
  > left (
      left mul: Expr lhs "*" Expr rhs
    | left div: Expr lhs "/" Expr rhs
  )
  > left (
      left add: Expr lhs "+" Expr rhs
    | left sub: Expr lhs "-" Expr rhs
  )
  > non-assoc (
      non-assoc eq: Expr lhs "==" Expr rhs
    | non-assoc neq: Expr lhs "!=" Expr rhs
    | non-assoc geq: Expr lhs "\>=" Expr rhs
    | non-assoc leq: Expr lhs "\<=" Expr rhs
    | non-assoc lt: Expr lhs "\<" Expr rhs
    | non-assoc gt: Expr lhs "\>" Expr rhs
    | non-assoc \in: Expr lhs "in" Expr rhs
    | non-assoc like: Expr lhs "like" Expr rhs
  )
  > left and: Expr lhs "&&" Expr rhs
  > left or: Expr lhs "||" Expr rhs
  ;
  

// Entity Ids  
syntax EId = Id \ Primitives;
  
keyword Primitives
  = "int" | "str" | "bool" | "text" | "float" | "blob" | "freetext" ;
  

// Variable Ids
syntax VId =  Id \ "true" \ "false" \ "null";

syntax Bool = "true" | False: "false";

syntax Obj = Label? labelOpt EId entity "{" {KeyVal ","}* keyVals "}";
  
syntax Label = "@" VId label;
  
syntax KeyVal 
  = Id feature ":" Expr value
  // needed for insert/update from workingset so that uuids can be used as identities
  | "@id" ":" Expr value 
  ;
  

// textual encoding of reference
lexical UUID = "#"[\-a-zA-Z0-9]+ !>> [\-a-zA-Z0-9];

// todo: escaping etc.
lexical Str = [\"] ![\"]* [\"];

lexical Int
  = [1-9][0-9]* !>> [0-9]
  | [0]
  ;
  