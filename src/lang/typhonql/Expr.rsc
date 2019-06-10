module lang::typhonql::Expr

extend lang::std::Layout;
extend lang::std::Id;
extend lang::typhonql::Type; // EId

syntax Expr
  = Attr: VId var "." Id attr
  | Var: VId 
  | Int: Int
  | Str: Str
  | Obj: Obj // for use in insert and allow nesting of objects
  | Null: "null"
  | Pos: "+" Expr arg
  | Neg: "-" Expr arg
  | Call: VId name "(" {Expr ","}* args ")"
  | Not: "!" Expr arg
  > left (
      left Mul: Expr lhs "*" Expr rhs
    | left Div: Expr lhs "/" Expr rhs
  )
  > left (
      left Add: Expr lhs "+" Expr rhs
    | left Sub: Expr lhs "-" Expr rhs
  )
  | non-assoc (
      non-assoc Eq: Expr lhs "==" Expr rhs
    | non-assoc NEq: Expr lhs "!=" Expr rhs
    | non-assoc GEq: Expr lhs "\>=" Expr rhs
    | non-assoc LEq: Expr lhs "\<=" Expr rhs
    | non-assoc LT: Expr lhs "\<" Expr rhs
    | non-assoc GT: Expr lhs "\>" Expr rhs
    | non-assoc In: Expr lhs "in" Expr rhs
    | non-assoc Like: Expr lhs "like" Expr rhs
  )
  > left And: Expr lhs "&&" Expr rhs
  | left Or: Expr lhs "||" Expr rhs
  ;
  

syntax VId = Var: Id \ "true" \ "false" ;

syntax Bool = True: "true" | False: "false";

syntax Obj = Label? labelOpt EId entity "{" {KeyVal ","}* keyVals "}";
  
syntax Label = "@" VId label;
  
syntax KeyVal = Id feature ":" Expr value;


// todo: escaping etc.
lexical Str = [\"] ![\"]* [\"];

lexical Int
  = [1-9][0-9]* !>> [0-9]
  | [0]
  ;
  
