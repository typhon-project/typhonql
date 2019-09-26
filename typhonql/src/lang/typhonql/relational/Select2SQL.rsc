module lang::typhonql::relational::Select2SQL

import lang::typhonql::TDBC;
import lang::typhonql::relational::SQL;
import lang::typhonql::relational::Util;

import lang::typhonml::Util; // Schema
import lang::typhonml::TyphonML;

import ParseTree;
import ValueIO;
import Set;
import IO;
import String;

/*

Approach:
 - convert all paths, to SQL paths.
 - add all tables from all paths to the from
 - [subsumed by the previous point: add all bindings to the from]
 - add all attrs of non-attr-end-points of paths, and plain vars (which are entities) to the select
     including all transitively reachable attributes through containment references.
 - add all paths > 1 as where clauses
 - in expression contexts use last element of path as result (attr itself, or typhon_id if ref)

TODO:
- aggregation
- "as" in TyphonQL
- always return the typhon id, no matter what.
*/


alias Env = map[str var, str entity];

alias SQLPath = list[PathElement];

data PathElement 
  = root(As as, str entity)
  | identity(As as, str entity)
  | child(As as, str entity, str role)
  | junction(As junction, As as, str entity, str role, str toRole)
  | attr(str name)
  ;

// the loc identifies the source expression of the path
alias PathMap = map[loc, list[SQLPath]];


list[SQLStat] compile2sql((Request)`<Query q>`, Schema s)
  = [ select2sql(q, s) ];

SQLStat select2sql((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs>`, Schema s) 
  = select2sql((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where true`, s);



bool allPathsEndInAttr(PathMap paths) 
  = ( true | it && p[-1] is attr | /SQLPath p := paths ); 

SQLStat select2sql(q:(Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ es>`, Schema s) {
  Env env = ( "<x>": "<e>" | (Binding)`<EId e> <VId x>` <- q.bindings ); 
  
  PathMap rps = resultPaths(rs, env, s);  
  //assert allPathsEndInAttr(rps): "non-attribute path in results";
  
  PathMap wps = wherePaths(es, env, s);

  PathMap allPaths = wps + rps;
  
  return select(dup(pathsToResultExprs(rps)), dup(pathsToFroms(allPaths))
    , [where(pathsToWheres(allPaths) + wheres2sql(es, allPaths))]); 
}

list[SQLExpr] pathsToResultExprs(PathMap paths)
  = [ path2expr(p) | /SQLPath p := paths ];

list[As] pathsToFroms(PathMap paths) = [ a | /As a := paths ];
  
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
      cs += [SQLExpr::equ(column(tbl2, fkName(from.entity, to.entity, to.role)), column(tbl1, typhonId(from.entity)))];
    }
    if (to is junction) {
      cs += [equ(column(to.junction.name, junctionFkName(from.entity, to.role)), column(tbl1, typhonId(from.entity))),
        equ(column(to.junction.name, junctionFkName(to.entity, to.toRole)), column(tbl2, typhonId(to.entity)))];
    }
  }
  return cs;
}

list[SQLExpr] wheres2sql({Expr ","}+ es, PathMap paths) 
  = [ expr2sql(e, paths) | Expr e <- es ];
   

/*
 * Converting entity/attr refs to paths consisting of foreign keys and junction tables
 */

PathMap resultPaths({Result ","}+ rs, map[str, str] env, Schema s) 
  = ( e@\loc: path2sql(e, env, s /*, trans=true*/) | /Expr e := rs, isTableExpr(e) ); 

PathMap wherePaths({Expr ","}+ es, map[str, str] env, Schema s) 
  = ( e@\loc: path2sql(e, env, s) | /Expr e := es, isTableExpr(e) ); 


bool isTableExpr(Expr e) =  e is attr || e is var || e is key;


str varForTarget(Id f) = "<f>$<f@\loc.offset>";

str varForJunction(Id f) = "junction_<f>$<f@\loc.offset>";

str varForClosure(str f, int i, loc l) = "<f>_<i>_$<l.offset>"; 

 
list[SQLPath] path2sql(Expr e, map[str, str] env, Schema s, bool trans = false) {
  SQLPath path;
  
  assert isTableExpr(e);
  
  switch (e) {
    case (Expr)`<VId x>`: {
      str entity = env["<x>"];
      path = [root(as(tableName(entity), "<x>"), entity)];
    }

    case (Expr)`<VId x>.@id`: {
      str entity = env["<x>"];
      path = [identity(as(tableName(entity), "<x>"), entity)];
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

list[SQLPath] containmentClosure(SQLPath p, Schema s, loc org) {
  // NB: this does not terminate if there are cycles in the containment relation
  // should be enforced by typhonML
  list[SQLPath] paths = [];
  Rels rels = symmetricReduction(s.rels);

  //println("Computing containment closure");
  

  int i = 0; // to make vars unique

  set[SQLPath] todo = {p};
  set[str] done = {};
  
  while (todo != {}) {
    //println("todo = <todo>");
    //println("done = <done>");
    <current, todo> = takeOneFrom(todo);
    //println("CURRENT: <current>");
    target = current[-1];
    //println("target = <target>");
    if (target is attr) {
      paths += [current];
    }
    else if (target is child || target is root, target.entity notin done) {
      // to break recursive containment (e.g. Comment.responses :-> Comment [*]
      // NB: in other words, this function does not work for recursive containment.
      done += {target.entity}; 
      paths += [ current + [attr(x)] | <str x, _> <- s.attrs[target.entity] ];
      todo += { current + [child(as(tableName(to), varForClosure(fromRole, i, org)), to, fromRole)] 
                    | <_, fromRole, _, _, str to, true> <- rels[target.entity] };
    }
    else {
      paths += [current + [attr(x)] | <str x, _> <- s.attrs[target.entity] ];
    } 
    
    i += 1;
  }
  
  //iprintln(paths);
  return paths;  
}

/*
 * Convert expressions to SQL expressions using paths for attribute and entity references
 */
 
SQLPath lookupPath(Expr e, PathMap paths) {
  assert isTableExpr(e) : "lookup of path not associated with attr/entity ref";
  assert size(paths[e@\loc]) == 1: "more than one path for path used in where clause";
  return paths[e@\loc][0];
}  

  
SQLExpr path2expr(SQLPath path) {
  assert path != []: "empty path";
  
  switch (path) {
    case [root(As a, str e)]:
      return column(a.name, typhonId(e));

    case [identity(As a, str e)]:
      return column(a.name, typhonId(e));
      
    case [*_, PathElement elt, attr(str x)]:
      return column(elt.as.name, columnName(x, elt.entity));
      
    case [*_, PathElement elt, child(As a, str e, _)]:
      return column(a.name, typhonId(e));
      
    case [*_, PathElement elt, junction(As j, As a, str e, str role, _)]:
      return column(a.name, junctionFkName(e, role));
  }
}



SQLExpr expr2sql(e:(Expr)`<VId x>.<{Id "."}+ ids>`, PathMap paths)
  = path2expr(lookupPath(e, paths));

SQLExpr expr2sql(e:(Expr)`<VId x>`, PathMap paths)
  = path2expr(lookupPath(e, paths));

SQLExpr expr2sql(e:(Expr)`<VId x>.@id`, PathMap paths)
  = path2expr(lookupPath(e, paths));

SQLExpr expr2sql((Expr)`?`, PathMap paths) = placeholder();

SQLExpr expr2sql((Expr)`<Int i>`, PathMap paths) = lit(integer(toInt("<i>")));

SQLExpr expr2sql((Expr)`<Real r>`, PathMap paths) = lit(decimal(toReal("<r>")));

SQLExpr expr2sql((Expr)`<Str s>`, PathMap paths) = lit(text("<s>"[1..-1]));

SQLExpr expr2sql((Expr)`<DateTime d>`, PathMap paths) = lit(dateTime(readTextValueString(#datetime, "<d>")));

SQLExpr expr2sql((Expr)`true`, PathMap paths) = lit(boolean(true));

SQLExpr expr2sql((Expr)`false`, PathMap paths) = lit(boolean(false));

SQLExpr expr2sql((Expr)`(<Expr e>)`, PathMap paths) = expr2sql(e, paths);

SQLExpr expr2sql((Expr)`null`, PathMap paths) = lit(null());

SQLExpr expr2sql((Expr)`+<Expr e>`, PathMap paths) = pos(expr2sql(e, paths));

SQLExpr expr2sql((Expr)`-<Expr e>`, PathMap paths) = neg(expr2sql(e, paths));

SQLExpr expr2sql((Expr)`!<Expr e>`, PathMap paths) = not(expr2sql(e, paths));

SQLExpr expr2sql((Expr)`<Expr lhs> * <Expr rhs>`, PathMap paths) 
  = mul(expr2sql(lhs, paths), expr2sql(rhs, paths));

SQLExpr expr2sql((Expr)`<Expr lhs> / <Expr rhs>`, PathMap paths) 
  = div(expr2sql(lhs, paths), expr2sql(rhs, paths));

SQLExpr expr2sql((Expr)`<Expr lhs> + <Expr rhs>`, PathMap paths) 
  = add(expr2sql(lhs, paths), expr2sql(rhs, paths));

SQLExpr expr2sql((Expr)`<Expr lhs> - <Expr rhs>`, PathMap paths) 
  = sub(expr2sql(lhs, paths), expr2sql(rhs, paths));

SQLExpr expr2sql((Expr)`<Expr lhs> == <Expr rhs>`, PathMap paths) 
  = equ(expr2sql(lhs, paths), expr2sql(rhs, paths));

SQLExpr expr2sql((Expr)`<Expr lhs> != <Expr rhs>`, PathMap paths) 
  = neq(expr2sql(lhs, paths), expr2sql(rhs, paths));

SQLExpr expr2sql((Expr)`<Expr lhs> \>= <Expr rhs>`, PathMap paths) 
  = geq(expr2sql(lhs, paths), expr2sql(rhs, paths));

SQLExpr expr2sql((Expr)`<Expr lhs> \<= <Expr rhs>`, PathMap paths) 
  = leq(expr2sql(lhs, paths), expr2sql(rhs, paths));

SQLExpr expr2sql((Expr)`<Expr lhs> \> <Expr rhs>`, PathMap paths) 
  = gt(expr2sql(lhs, paths), expr2sql(rhs, paths));

SQLExpr expr2sql((Expr)`<Expr lhs> \< <Expr rhs>`, PathMap paths) 
  = lt(expr2sql(lhs, paths), expr2sql(rhs, paths));

SQLExpr expr2sql((Expr)`<Expr lhs> like <Expr rhs>`, PathMap paths) 
  = like(expr2sql(lhs, paths), expr2sql(rhs, paths));

SQLExpr expr2sql((Expr)`<Expr lhs> && <Expr rhs>`, PathMap paths) 
  = and(expr2sql(lhs, paths), expr2sql(rhs, paths));

SQLExpr expr2sql((Expr)`<Expr lhs> || <Expr rhs>`, PathMap paths) 
  = or(expr2sql(lhs, paths), expr2sql(rhs, paths));


default SQLExpr expr2sql(Expr e, PathMap _) { throw "Unsupported expression: <e>"; }

