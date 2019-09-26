module lang::typhonql::Eval

import lang::typhonql::Expr;
import lang::typhonql::WorkingSet;
import lang::typhonql::util::UUID;

/*

This module contains an interpreter of the TyphonQL expression sub-language.
The eval functions receive an expression, and environment (mapping variable name 
to entities), and a WorkingSet as scope. The latter is used to navigate
across references to evaluate path expressions.

- `evalResult` evaluates expressions in the "select" clause of a query to an entity
- `eval` evaluates expressions in where clauses to a value 

*/


Entity evalResult((Expr)`<VId x>.<{Id "."}+ xs>`, map[str, Entity] env, WorkingSet scope) 
  = navigateEntity(xs, e, scope)
  when
    Entity e := env["<x>"];


Entity evalResult((Expr)`<VId x>.@id`, map[str, Entity] env, WorkingSet scope) 
  = e
  when
    Entity e := env["<x>"];
    
Entity evalResult((Expr)`<VId x>`, map[str, Entity] env, WorkingSet scope)
  = e 
  when
    Entity e := env["<x>"];


default Entity evalResult(Expr e, map[str, Entity] env, WorkingSet scope)
  = <"anonymous", makeUUID(), ("value": eval(e, env, scope))>;

/*
 * Eval in where clauses
 */

value eval((Expr)`<VId x>.<{Id "."}+ xs>`, map[str, Entity] env, WorkingSet scope) 
  = navigate(xs, e, scope)
  when
    Entity e := env["<x>"];
  
value eval((Expr)`<VId x>.@id`, map[str, Entity] env, WorkingSet scope) 
  = uuid(e.uuid)
  when
    Entity e := env["<x>"];


value eval((Expr)`<VId x>`, map[str, Entity] env, WorkingSet scope) 
  = e
  when
    Entity e := env["<x>"];
  
value eval((Expr)`<Int n>`, map[str, Entity] env, WorkingSet scope) 
  = toInt("<n>");
  
value eval((Expr)`<Real r>`, map[str, Entity] env, WorkingSet scope) 
  = toReal("<r>");
  
value eval((Expr)`<Bool b>`, map[str, Entity] env, WorkingSet scope) 
  = ((Bool)`true` := b);
  
value eval((Expr)`<Str s>`, map[str, Entity] env, WorkingSet scope) 
  = "<s>"[1..-1];
  
value eval((Expr)`<DateTime d>`, map[str, Entity] env, WorkingSet scope) 
  = readTextValueString(#datetime, "<d>");
  
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

value navigate({Id "."}+ xs, Entity e, WorkingSet scope) {
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

Entity navigateEntity({Id "."}+ xs, Entity e, WorkingSet scope) {
  Entity cur = e;
  
  for (Id x <- xs) {
    str fld = "<x>";
    if (fld notin cur.fields) {
       return null();
    }
  
    if (Entity to := cur.fields[fld]) {
      cur = to;
    } 
    else if (uuid(str u) := cur.fields[fld]) {
      cur = lookupEntity(u, scope);
    }
    else {
      return cur;
    }
    
  }
  
  assert Entity _ := cur: "navigateEntity should return entity";
  
  return cur;
}

