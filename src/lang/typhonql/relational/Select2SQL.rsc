module lang::typhonql::relational::Select2SQL

import lang::typhonql::Query;
import lang::typhonql::relational::SQL;
import lang::typhonql::relational::Util;

import lang::typhonml::Util; // Schema
import lang::typhonml::TyphonML;

import ParseTree;
import Set;
import IO;

// for now, no aggregation


alias Env = map[str var, str entity];

SQLStat select2sql((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs>`, Schema s) 
  = select2sql((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where true`, s);


/*

Approach:
 - convert all paths, to SQL paths.
 - add all tables from all paths to the from
 - [subsumed by the previous point: add all bindings to the from]
 - add all attrs of non-attr-end-points of paths, and plain vars (which are entities) to the select
     including all transitively reachable attributes through containment references.
 - add all paths > 1 as where clauses
 - in expression contexts use last element of path as result (attr itself, or typhon_id if ref)

*/

bool allPathsEndInAttr(PathMap paths) {
  for (/SQLPath p := paths) {
    if (!(p[-1] is attr)) {
      return false;
    } 
  }
  return true;
}

SQLStat select2sql(q:(Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ es>`, Schema s) {
  map[str, str] env = ( "<x>": "<e>" | (Binding)`<EId e> <VId x>` <- q.bindings ); 
  
  PathMap wps = wherePaths(es, env, s);
  
  
  PathMap rps = resultPaths(rs, env, s);
  
  assert allPathsEndInAttr(rps): "non-attribute path in results";
  
  
  PathMap allPaths = wps + rps;
  
  
  return select(pathsToResultExprs(rps), dup(pathsToFroms(allPaths))
    , [where(pathsToWheres(allPaths) + wheres2sql(es, allPaths))]); 
}

list[SQLExpr] pathsToResultExprs(PathMap paths) 
  = [ column(p[-2].as.name, p[-1].name) | /SQLPath p := paths ];

list[As] pathsToFroms(PathMap paths) 
  = [ a | /As a := paths ];
  
list[SQLExpr] pathsToWheres(PathMap paths) 
  = [ *pathToWheres(p) | /SQLPath p := paths ];

list[SQLExpr] pathToWheres(SQLPath p) {
  if (size(p) <= 1) {
    return [];
  }
  list[SQLExpr] cs = [];
  for (int i <- [0..size(p)]) {
    if (i == size(p) - 1 || (i == size(p) - 2 && p[-1] is attr)) {
      break; // skip last attribute
    }
    from = p[i];
    to = p[i+1];
    tbl1 = from.as.name;
    tbl2 = to.as.name;
    if (to is child) {
      cs += [SQLExpr::eq(column(tbl2, fkName(to.role)), column(tbl1, typhonId(from.entity)))];
    }
    if (to is junction) {
      cs += [equ(column(to.junction.name, junctionFkName(from.entity, to.role)), column(tbl1, typhonId(from.entity))),
        equ(column(to.junction.name, junctionFkName(to.entity, to.toRole)), column(tbl2, typhonId(to.entity)))];
    }
  }
  return cs;
}

alias SQLPath = list[PathElement];

alias PathMap = map[loc, list[SQLPath]];

data PathElement 
  = root(As as, str entity)
  | child(As as, str entity, str role)
  | junction(As junction, As as, str entity, str role, str toRole)
  | attr(str name)
  ;


list[SQLExpr] wheres2sql({Expr ","}+ es, PathMap paths) 
  = [ expr2sql(e, paths) | Expr e <- es ];
   

SQLExpr expr2sql(e:(Expr)`<VId x>.<{Id "."}+ ids>`, PathMap paths)
  = path2expr(lookupPath(e, paths));


SQLExpr expr2sql((Expr)`<Expr lhs> == <Expr rhs>`, PathMap paths) 
  = equ(expr2sql(lhs, paths), expr2sql(rhs, paths));


SQLExpr expr2sql((Expr)`true`, PathMap paths) = lit(boolean(true));

SQLExpr expr2sql((Expr)`false`, PathMap paths) = lit(boolean(false));

SQLExpr expr2sql((Expr)`<Str s>`, PathMap paths) = lit(text("<s>"[1..-1]));


SQLPath lookupPath(Expr e, PathMap paths) {
  assert isTableExpr(e);
  assert size(paths[e@\loc]) == 1;
  return paths[e@\loc][0];
}  

SQLExpr path2expr(SQLPath path) {
  if (size(path) == 1) {
    return column(path[0].as.name, typhonId(root.entity));
  }
  target = path[-1];
  if (target is attr) {
    return column(path[-2].as.name, target.name);
  }
  if (target is child) {
    return column(target.as.name, typhonId(target.entity));
  }
  return column(target.as.name, junctionFkName(target.entity, target.role));
}

PathMap resultPaths({Result ","}+ rs, map[str, str] env, Schema s) 
  = ( e@\loc: path2sql(e, env, s, trans=true) | /Expr e := rs, isTableExpr(e) ); 

PathMap wherePaths({Expr ","}+ es, map[str, str] env, Schema s) 
  = ( e@\loc: path2sql(e, env, s) | /Expr e := es, isTableExpr(e) ); 


bool isTableExpr(Expr e) =  e is attr || e is var;


str varForTarget(Id f) = "<f>$<f@\loc.offset>";

str varForJunction(Id f) = "junction_<f>$<f@\loc.offset>";

str varForClosure(str f, int i, loc l) = "<f>_<i>_$<origin.offset>"; 

 

// NB: this does not terminate if there are cycles in the containment relation
// should be enforced by typhonML
list[SQLPath] containmentClosure(SQLPath p, Schema s, loc origin) {
  list[SQLPath] paths = [];
  Rels rels = symmetricReduction(s.rels);

  int i = 0; // to make vars unique

  set[SQLPath] todo = {p};
  
  while (todo != {}) {
    <current, todo> = takeOneFrom(todo);
    target = current[-1];
    
    if (target is attr) {
      paths += [current];
    }
    else if (target is child || target is root) {
      paths += [ p + [attr(x)] | <str x, _> <- s.attrs[target.entity] ];
      todo += { p + [child(as(tableName(to), varForClosure(fromRole, i, org)), to, fromRole)] 
                    | <_, fromRole, _, _, str to, true> <- rels[target.entity] };
    }
    else {
      paths += [current + [attr(x)] | <str x, _> <- s.attrs[target.entity] ];
    } 
    
    i += 1;
  }
  
  return paths;  
}
  
list[SQLPath] path2sql(Expr e, map[str, str] env, Schema s, bool trans = false) {
  SQLPath path;
  
  assert isTableExpr(e);
  
  switch (e) {
    case (Expr)`<VId x>`: {
      str entity = env["<x>"];
      path = [root(as(tableName(entity), "<x>"), entity)];
    }

    case (Expr)`<VId x>.<{Id "."}+ fs>`: {
	  str entity = env["<x>"];
	  path = [root(as(tableName(entity), "<x>"), entity)];
	  
	  for (Id f <- fs) {
	    str role = "<f>"; 
	    if (<entity, _, role, str toRole, _, str to, true> <- s.rels) {
	      path += [child(as(tableName(to), varForTarget(f)), to, toRole /* ??? */)];
	      entity = to;
	    }
	    else if (<str to, _, str toRole, role, _, entity, true> <- s.rels) {
	      path += [child(as(tableName(to), varForTarget(f)), to, role /* ??? */)];
	      entity = to;
	    }
	    else if (<entity, _, role, str toRole, _, str to, false> <- s.rels) {
	      path += [junction(as(junctionTableName(entity, role, to, toRole), varForJunction(f)),
	                        as(tableName(to), varForTarget(f)), to, role, toRole)];
	      entity = to;
	    }
	    else {
	      path += [attr(role)];
	      assert size(path) - 1 == size([ f | Id f <- fs]): "navigation after attribute";
	    }
	  }
	}
	
  }
  
  return trans ? containmentClosure(path, s, e@\loc) : [path];
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


// NB: .entity is save, because a path always starts with root
list[SQLExpr] attrsReachedByPaths(map[loc, SQLPath] paths, Schema s) 
  = [ *navigate(path[0].entity, p, s) | SQLPath p <- paths<1> ]; 



//list[SQLExpr] navigate(SQLPath p, Schema s) {
//  s.rels = symmetricReduction(s.rels);
//  
//  if (size(p) == 1) {
//    // last element
//    switch (p[0]) {
//      case root(as(str tbl, str name), str entity): {
//        es = [ column(name, fld) | <entity, fld, _> <- s.attrs ];
//        for ((<entity, _, str role, str toRole, _, str to, true> <- s.rels) {
//          
//        }
//      }
//    }
//  }
//}


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


