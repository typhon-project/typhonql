module lang::typhonql::Script

import lang::typhonql::TDBC;


data Script
  = script(Request req, list[Stm] body);
  
  
/*

Todo updates with inserts you'll get something like:

let x = query(p0, Q0) {
  ...
    let z = query(pn, Qn) {
      foreach (... in x... z)
        if ( ... recombine where's) {
          execute(p, insert Person {@id: ?, ... }, newId )
          execute(p, update(?), [x/.../z.id])
}


*/
  
  
data Stm
  = ifThen(Expr cond, list[Stm] body)
  | forEach(lrel[str, Expr] bindings, list[Stm] body)
  | let(lrel[str, Expr] bindings, list[Stm] body)
  | letRec(lrel[str, Expr] bindings, list[Stm] body)
  | yield(str entity, Expr expr)
  | execute(Place place, value stat, list[Expr] args)
  ;
  

data Expr
  = query(Place place, value query, list[Expr] args)
  | attr(str var, list[str] props)
  | id(str var)
  | new(str entity, map[str, Expr] props)
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