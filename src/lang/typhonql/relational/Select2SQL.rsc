module lang::typhonql::relational::Select2SQL

import lang::typhonql::Query;
import lang::typhonql::relational::SQL;
import lang::typhonql::relational::Util;

import lang::typhonml::Util; // Schema
import lang::typhonml::TyphonML;

import ParseTree;

// for now, no aggregation


alias Env = map[str var, str entity];

list[SQLStat] select2sql((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs>`, Schema s) 
  = select2sql((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where true`, s);

list[SQLStat] select2sql((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ es>`, Schema s) 
  = [];



// path navigations need additional foreign key where clauses, also when they are in the result
// but not used in wheres
// from User p select p.name, p.orders
// -> select p.name as `Person.name`, Order_entity.* as `Person.orders` from User_entity as p, Order_entity as _x
//   where Order_entity.user_id = p._typhon_id

//list[SQLExpr] wheres2sql({Expr ","}+ 


// not all participating entities have to be specified in the bindings section
// because of path navigation. 
set[str] participatingEntities(Query q, Schema s) {
  map[str, str] env = ( "<x>": "<e>" | (Binding)`<EId e> <VId x>` <- q.bindings ); 
  set[str] entities = env<1>;
   
  visit (q) {
    case (Expr)`<VId x>.<{Id "."}+ fs>`: {
      entities += toSet(navigate(env["<x>"], [ "<f>" | Id f <- fs ]), s);
    }
  }
}

/*
 
Paths
 - always starts at a variable of some type

do
 - always add all junction tables to from clause with a unique name for this path
 - always add all owned tables in the chain to the from clause also identified for this path
 - if a path is in the select of the query
     if path ends in a (local) entity
       add all attributes of the entity to the select clause (transitively including contained components)
     if path ends in an outside entity
       add the last junction table to the select clause
 - for a path A.f1....fn with identity x
    - if fn is attribute
       add where clauses (accounting for junction tables and ownership)
           if A owns f1 (a B): B.f1_id = A.id
           else: A_f1_B.A_f1_id = A.id, A_f1_B.B_f1_id = B.id
                

 
*/

// the strings here are

alias SQLPath = list[PathElement];
 
data PathElement 
  = root(As entity)
  | child(As target)
  | junction(As junction, As target)
  | attr(str name)
  ;

str varForTarget(Id f) = "<f>$<f@\loc.offset>";

str varForJunction(Id f) = "junction_<f>$<f@\loc.offset>";

  
SQLPath path2sql((Expr)`<VId x>.<{Id "."}+ fs>`, map[str, str] env, Schema s) {
  str entity = env["<x>"];
  SQLPath path = [root(as(tableName(entity), "<x>"))];
  
  
  for (Id f <- fs) {
    str role = "<f>"; 
    if (<entity, _, role, str toRole, _, str to, true> <- s.rels) {
      path += [child(as(tableName(to), varForTarget(f)))];
      entity = to;
    }
    else if (<str to, _, str toRole, role, _, entity, true> <- s.rels) {
      path += [child(as(tableName(entity), varForTarget(f)))];
      entity = to;
    }
    else if (<entity, _, role, str toRole, _, str to, false> <- s.rels) {
      path += [junction(as(junctionTableName(entity, role, to, toRole), varForJunction(f)),
                        as(tableName(to), varForTarget(f)))];
      entity = to;
    }
    else {
      path += [attr(role)];
      break;
    }
  }
  
  return path;
} 

test bool navigateUsers() =
  navigate("User", ["orders", "products", "review"], myDbSchema)
    == ["User","Order","Product","Review"];

// TODO: make this produce tables (including junction tables)
// (nb: need to find the canonical thing again for containments
// PER path we need to add where clauses, AND have junction tables (with unique names)

list[str] navigate(str from, list[str] path, Schema s) {
  if (path == []) {
    return [from];
  }
  str role = path[0];
  if (<from, _, role, _, _, str to, _> <- s.rels) {
    return [from] + navigate(to, path[1..], s);
  } // else it's an attribute
  return [from];
}

