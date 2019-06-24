module lang::typhonql::recombine::RecombineJava

/*
 Todo: group fields in result set according to entity type so that we return partial entities
*/

data Stm
  = forEach(lrel[str, str] bindings, list[Stm] body)
  | ifThen(Expr cond, list[Stm] body)
  | yield(str entity, Expr result)
  ;
  
 // follows the exact same structure as TyphonQL expressions
 // except for object and list literals.
 data Expr 
  = attr(str var, list[str] props)
  | var(str name) 
  | key(str var)
  | \int(int intVal)
  | \str(str strVal)
  | \bool(bool boolVal)
  | uuid(str uuid)
  | null()
  | pos(Expr arg)
  | neg(Expr arg)
  | call(str name, list[Expr] args)
  | not(Expr arg)
  | mul(Expr lhs, Expr rhs)
  | div(Expr lhs, Expr rhs)
  | add(Expr lhs, Expr rhs)
  | sub(Expr lhs, Expr rhs)
  | eq(Expr lhs, Expr rhs)
  | neq(Expr lhs, Expr rhs)
  | geq(Expr lhs, Expr rhs)
  | leq(Expr lhs, Expr rhs)
  | lt(Expr lhs, Expr rhs)
  | gt(Expr lhs, Expr rhs)
  | \in(Expr lhs, Expr rhs)
  | like(Expr lhs, Expr rhs)
  | and(Expr lhs, Expr rhs)
  | or(Expr lhs, Expr rhs)
  ;
