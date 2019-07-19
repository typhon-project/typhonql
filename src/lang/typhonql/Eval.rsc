module lang::typhonql::Eval

import lang::typhonql::Expr;
import lang::typhonql::WorkingSet;


value eval((Expr)`<VId x>.<{Id ","}+ xs>`, map[str, Entity] env, WorkingSet scope) 
  = navigate(xs, e, scope)
  when
    Entity e := env["<x>"];
  
value eval((Expr)`<VId x>.@id`, map[str, Entity] env, WorkingSet scope) 
  = uuid(e.uuid)
  when
    Entity e := env["<x>"];
  
value eval((Expr)`<Int n>`, map[str, Entity] env, WorkingSet scope) 
  = toInt("<n>");
  
value eval((Expr)`<Bool b>`, map[str, Entity] env, WorkingSet scope) 
  = ((Bool)`true` := b);
  
value eval((Expr)`<UUID u>`, map[str, Entity] env, WorkingSet scope) 
  = uuid("<u>"[1..]);
  
value eval((Expr)`(<Expr e>)`, map[str, Entity] env, WorkingSet scope) 
  = eval(e, env, scope);
  
value eval((Expr)`null`, map[str, Entity] env, WorkingSet scope) 
  = null();
  
value eval((Expr)`+<Expr e>`, map[str, Entity] env, WorkingSet scope) 
  = n
  when
    int n := eval(e, env, scope);
  
value eval((Expr)`-<Expr e>`, map[str, Entity] env, WorkingSet scope) 
  = -n
  when
    int n := eval(e, env, scope);
  
value eval((Expr)`!<Expr e>`, map[str, Entity] env, WorkingSet scope) 
  = !b
  when
    bool b := eval(e, env, scope);
  

value eval((Expr)`<Expr lhs> * <Expr rhs>`, map[str, Entity] env, WorkingSet scope) 
  = a * b
  when
    num a := eval(lhs, env, scope),
    num b := eval(rhs, env, scope);
  
value eval((Expr)`<Expr lhs> / <Expr rhs>`, map[str, Entity] env, WorkingSet scope) 
  = a / b
  when
    num a := eval(lhs, env, scope),
    num b := eval(rhs, env, scope);
  
value eval((Expr)`<Expr lhs> + <Expr rhs>`, map[str, Entity] env, WorkingSet scope) 
  = a + b
  when
    num a := eval(lhs, env, scope),
    num b := eval(rhs, env, scope);
  
  
value eval((Expr)`<Expr lhs> - <Expr rhs>`, map[str, Entity] env, WorkingSet scope) 
  = a - b
  when
    num a := eval(lhs, env, scope),
    num b := eval(rhs, env, scope);

  
value eval((Expr)`<Expr lhs> == <Expr rhs>`, map[str, Entity] env, WorkingSet scope) 
  = a == b
  when
    value a := eval(lhs, env, scope),
    value b := eval(rhs, env, scope);
  
  
value eval((Expr)`<Expr lhs> != <Expr rhs>`, map[str, Entity] env, WorkingSet scope) 
  = a != b
  when
    value a := eval(lhs, env, scope),
    value b := eval(rhs, env, scope);
  
value eval((Expr)`<Expr lhs> \>= <Expr rhs>`, map[str, Entity] env, WorkingSet scope) 
  = a >= b
  when
    num a := eval(lhs, env, scope),
    num b := eval(rhs, env, scope);

value eval((Expr)`<Expr lhs> \<= <Expr rhs>`, map[str, Entity] env, WorkingSet scope) 
  = a <= b
  when
    num a := eval(lhs, env, scope),
    num b := eval(rhs, env, scope);
  
value eval((Expr)`<Expr lhs> \> <Expr rhs>`, map[str, Entity] env, WorkingSet scope) 
  = a > b
  when
    num a := eval(lhs, env, scope),
    num b := eval(rhs, env, scope);

value eval((Expr)`<Expr lhs> \< <Expr rhs>`, map[str, Entity] env, WorkingSet scope) 
  = a < b
  when
    num a := eval(lhs, env, scope),
    num b := eval(rhs, env, scope);
  
value eval((Expr)`<Expr lhs> && <Expr rhs>`, map[str, Entity] env, WorkingSet scope) 
  = truthy(eval(lhs, env, scope)) && truthy(eval(rhs, env, scope)); 

value eval((Expr)`<Expr lhs> || <Expr rhs>`, map[str, Entity] env, WorkingSet scope) 
  = truthy(eval(lhs, env, scope)) || truthy(eval(rhs, env, scope)); 

default value eval(Expr e, map[str, Entity] env, WorkingSet scope) {
  throw "Unsupported expression <e>";
} 


bool truthy(false) = false;
bool truthy(0) = false;
bool truthy(0.0) = false;
bool truthy(null()) = false;
default bool truthy(value _) = true;

value lookupEntity(str uuid, WorkingSet scope) {
  for (str tipe <- scope, Entity e <- scope[tipe], e.uuid == uuid) {
    return e;
  }
  println("WARNING: could not find entity with id <uuid> in scope");
  return null();
}

value navigate({Id ","}+ xs, Entity e, WorkingSet scope) {
  value cur = e;
  for (Id x <- xs, Entity curEntity := cur) {
    str fld = "<x>";
    if (fld notin curEntity.fields) {
       return null();
    }
    cur = curEntity.fields[fld];
    if (uuid(str u) := cur) {
      cur = lookupEntity(u, scope);
    }
  }
  return cur;
}

