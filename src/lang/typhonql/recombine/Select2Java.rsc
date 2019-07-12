module lang::typhonql::recombine::Select2Java

import lang::typhonql::TDBC;
import lang::typhonql::recombine::MuJava;
import lang::typhonml::Util;


import List;

list[Stm] compile2java((Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs>`, Schema s) 
  = compile2java((Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where true`, s);

list[Stm] compile2java((Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ exprs>`, Schema s) {
  map[str, str] env = ( "<b.var>":  "<b.entity>" | Binding b <- bs );
  
  list[Stm] innerYields = [ yield(inferType(e, env, s), expr2java(e)) | (Result)`<Expr e>` <- rs ]; 
  list[Stm] nestedIfs = ( innerYields | [ifThen(expr2java(e), it)] | Expr e <- reverse( [ x | Expr x <- exprs ] ) ); 
  return [forEach([ <"<b.entity>", "<b.var>"> | Binding b <- bs ], nestedIfs)];
}

str inferType(e:(Expr)`<VId x>`, map[str, str] env, Schema s) = env["<x>"];

str inferType(e:(Expr)`<VId x>.@id`, map[str, str] env, Schema s) = env["<x>"];

str inferType(e:(Expr)`<VId x>.<{Id "."}+ ids>`, map[str, str] env, Schema s) {
  str entity = env["<x>"];
  for (Id id <- ids) {
    str fld = "<id>";
    if (<entity,  fld, _> <- s.attrs) {
      return entity;
    }
    if (<entity, _, fld, _, _, str to, _> <- s.rels) {
      entity = to;
    }
    else {
      throw "Invalid entity navigation <e> (could not find <fld> in <entity>)"; 
    }
  }
  return entity;
}

JavaExpr expr2java(e:(Expr)`<VId x>.<{Id "."}+ ids>`) = attr("<x>", [ "<p>" | Id p <- ids ]);

JavaExpr expr2java(e:(Expr)`<VId x>`) = var("<x>");

JavaExpr expr2java(e:(Expr)`<VId x>.@id`) = key("<x>");

JavaExpr expr2java((Expr)`?`) = placeholder();

JavaExpr expr2java((Expr)`<Int i>`) = \int(toInt("<i>"));

JavaExpr expr2java((Expr)`<Str s>`) = \str("<s>"[1..-1]);

JavaExpr expr2java((Expr)`true`) = \bool(true);

JavaExpr expr2java((Expr)`false`) = \bool(false);

JavaExpr expr2java((Expr)`<UUID uuid>`) = \str("<uuid>"[1..]);

JavaExpr expr2java((Expr)`(<Expr e>)`) = expr2java(e);

JavaExpr expr2java((Expr)`null`) = null();

JavaExpr expr2java((Expr)`+<Expr e>`) = pos(expr2java(e));

JavaExpr expr2java((Expr)`-<Expr e>`) = neg(expr2java(e));

JavaExpr expr2java((Expr)`!<Expr e>`) = not(expr2java(e));

JavaExpr expr2java((Expr)`<Expr lhs> * <Expr rhs>`) 
  = mul(expr2java(lhs), expr2java(rhs));

JavaExpr expr2java((Expr)`<Expr lhs> / <Expr rhs>`) 
  = div(expr2java(lhs), expr2java(rhs));

JavaExpr expr2java((Expr)`<Expr lhs> + <Expr rhs>`) 
  = add(expr2java(lhs), expr2java(rhs));

JavaExpr expr2java((Expr)`<Expr lhs> - <Expr rhs>`) 
  = sub(expr2java(lhs), expr2java(rhs));

JavaExpr expr2java((Expr)`<Expr lhs> == <Expr rhs>`) 
  = equ(expr2java(lhs), expr2java(rhs));

JavaExpr expr2java((Expr)`<Expr lhs> != <Expr rhs>`) 
  = neq(expr2java(lhs), expr2java(rhs));

JavaExpr expr2java((Expr)`<Expr lhs> \>= <Expr rhs>`) 
  = geq(expr2java(lhs), expr2java(rhs));

JavaExpr expr2java((Expr)`<Expr lhs> \<= <Expr rhs>`) 
  = leq(expr2java(lhs), expr2java(rhs));

JavaExpr expr2java((Expr)`<Expr lhs> \> <Expr rhs>`) 
  = gt(expr2java(lhs), expr2java(rhs));

JavaExpr expr2java((Expr)`<Expr lhs> \< <Expr rhs>`) 
  = lt(expr2java(lhs), expr2java(rhs));

JavaExpr expr2java((Expr)`<Expr lhs> like <Expr rhs>`) 
  = like(expr2java(lhs), expr2java(rhs));

JavaExpr expr2java((Expr)`<Expr lhs> && <Expr rhs>`) 
  = and(expr2java(lhs), expr2java(rhs));

JavaExpr expr2java((Expr)`<Expr lhs> || <Expr rhs>`) 
  = or(expr2java(lhs), expr2java(rhs));


default JavaExpr expr2java(Expr e) { throw "Unsupported expression: <e>"; }
