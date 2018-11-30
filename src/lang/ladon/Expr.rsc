module lang::ladon::Expr

extend lang::std::Layout;
extend lang::std::Id;

syntax Expr
  = VId var "." Id attr
  | VId 
  | Int
  | Str
  | "null"
  | "+" Expr
  | "-" Expr
  | "!" Expr
  > left (
      left Expr "*" Expr
    | left Expr "/" Expr
  )
  > left (
      left Expr "+" Expr
    | left Expr "-" Expr
  )
  | non-assoc (
      non-assoc Expr "==" Expr
    | non-assoc Expr "!=" Expr
    | non-assoc Expr "\>=" Expr
    | non-assoc Expr "\<=" Expr
    | non-assoc Expr "\<" Expr
    | non-assoc Expr "\>" Expr
    | non-assoc Expr "like" Expr
  )
  > left Expr "&&" Expr
  | left Expr "||" Expr
  ;
  

syntax VId = Id \ "true" \ "false" ;

syntax Bool = "true" | "false";

// todo: escaping etc.
lexical Str = [\"] ![\"]* [\"];

lexical Int
  = [1-9][0-9]* !>> [0-9]
  | [0]
  ;
  
