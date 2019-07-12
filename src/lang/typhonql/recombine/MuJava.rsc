module lang::typhonql::recombine::MuJava

/*
 Todo: group fields in result set according to entity type so that we return partial entities
*/

data Stm
  = forEach(lrel[str, str] bindings, list[Stm] body)
  | ifThen(JavaExpr cond, list[Stm] body)
  | yield(str entity, JavaExpr result)
  ;
  
 // follows the exact same structure as TyphonQL expressions
 // except for object and list literals.
 data JavaExpr 
  = attr(str var, list[str] props)
  | var(str name) 
  | key(str var)
  | \int(int intVal)
  | \str(str strVal)
  | \bool(bool boolVal)
  | uuid(str uuid)
  | null()
  | pos(JavaExpr arg)
  | neg(JavaExpr arg)
  | call(str name, list[JavaExpr] args)
  | not(JavaExpr arg)
  | mul(JavaExpr lhs, JavaExpr rhs)
  | div(JavaExpr lhs, JavaExpr rhs)
  | add(JavaExpr lhs, JavaExpr rhs)
  | sub(JavaExpr lhs, JavaExpr rhs)
  | equ(JavaExpr lhs, JavaExpr rhs)
  | neq(JavaExpr lhs, JavaExpr rhs)
  | geq(JavaExpr lhs, JavaExpr rhs)
  | leq(JavaExpr lhs, JavaExpr rhs)
  | lt(JavaExpr lhs, JavaExpr rhs)
  | gt(JavaExpr lhs, JavaExpr rhs)
  | \in(JavaExpr lhs, JavaExpr rhs)
  | like(JavaExpr lhs, JavaExpr rhs)
  | and(JavaExpr lhs, JavaExpr rhs)
  | or(JavaExpr lhs, JavaExpr rhs)
  ;
