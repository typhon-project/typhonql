module lang::typhonql::mongodb::Select2Find

import lang::typhonql::mongodb::DBCollection;
import lang::typhonql::TDBC;
import lang::typhonml::Util;

import String;
import List;
import IO;

/*

Approach:

containments become nested DBObjs (patterns)

wheres on entities should anded and put on the dbobj queries.

How to determine whether an entity becomes a collection
or anonymously nested?

I guess if it's contained, and there are no incoming xrefs to it the entity, otherwise, we need a reference identifier


entities to be retrieved:
- all entities x that have a path ending at it in the results
- all entities x that have a paths to an attr in x in the results

collections to be queried
- all collections of the from clause?

Todo: always return the typhon id




*/

lrel[str, CollMethod] compile2mongo((Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs>`, Schema s)
  = select2find((Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where true`, s, translateWheres=false);


// TODO: how to deal with multi entity finds?
lrel[str, CollMethod] compile2mongo(r:(Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}* es>`, Schema s, bool translateWheres = true) {
  Env env = ( "<b.var>": "<b.entity>" | Binding b <- bs );
  
  println("Compiling <r> to mongo");
  
  map[str, CollMethod] result = ( "<b.entity>": find(object([]), object([])) | Binding b <- bs );
  
  
  for ((Result)`<VId x>.<{Id "."}+ fs>` <- rs) {
    result[env["<x>"]].projection.props += [<"@id", \value(1)>, <"<fs>", \value(1)>];
  }
 
  // this is what you get if outside puts in the "true" placeholder...
  exprList = [ e | Expr e <- es ];
  translateWheres = !(size(exprList) == 1 && ((Expr)`true` := exprList[0]));
 
  for (translateWheres, Expr e <- es) {
    <coll, p> = expr2pattern(e, env);
    result[coll].query.props += [p];
  }
  
  iprintln(result);
  
  return [ <k, result[k]> | str k <- result ];
}

alias Env = map[str, str];


tuple[str, Prop] expr2pattern((Expr)`<Expr lhs> == <Expr rhs>`, Env env)
  = <coll, <path, expr2obj(other)>> 
  when
    <str coll, str path, Expr other> := split(lhs, rhs, env);
    
tuple[str, Prop] expr2pattern((Expr)`<Expr lhs> != <Expr rhs>`, Env env)
  = makeComparison("$ne", lhs, rhs, env);
  

tuple[str, Prop] expr2pattern((Expr)`<Expr lhs> \> <Expr rhs>`, Env env)
  = makeComparison("$gt", lhs, rhs, env);

tuple[str, Prop] expr2pattern((Expr)`<Expr lhs> \< <Expr rhs>`, Env env)
  = makeComparison("$lt", lhs, rhs, env);

tuple[str, Prop] expr2pattern((Expr)`<Expr lhs> \>= <Expr rhs>`, Env env)
  = makeComparison("$gte", lhs, rhs, env);

tuple[str, Prop] expr2pattern((Expr)`<Expr lhs> \<= <Expr rhs>`, Env env)
  = makeComparison("$lte", lhs, rhs, env);
  

default tuple[str, Prop] expr2pattern(Expr e, Env env) { 
  throw "Unsupported expression: <e>"; 
}

  
tuple[str, Prop] makeComparison(str op, Expr lhs, Expr rhs, Env env) 
  = <coll, <path, object([<op, expr2obj(other)>])>> 
  when
    <str coll, str path, Expr other> := split(lhs, rhs, env);
    
    
// NB: restriction is that the same collection cannot be queried with different vars
// also paths in vars now must end at  primitives.
 
tuple[str coll, str path, Expr other] split(Expr lhs, Expr rhs, Env env) {
  if ((Expr)`<VId x>.<{Id "."}+ fs>` := lhs) {
    return <env["<x>"], "<fs>", rhs>; 
  }
  else if ((Expr)`<VId x>.<{Id "."}+ fs>` := rhs) {
    return <env["<x>"], "<fs>", lhs>;
  }
  else {
    throw "One of binary expr must contain field navigation, but got: <lhs>, <rhs>";
  }
}

DBObject expr2obj((Expr)`?`) = placeholder();

DBObject expr2obj((Expr)`<Int i>`) = \value(toInt("<i>"));

DBObject expr2obj((Expr)`<Real r>`) = \value(toReal("<r>"));

// todo: unescaping
DBObject expr2obj((Expr)`<Str s>`) = \value("<s>"[1..-1]);

DBObject expr2obj((Expr)`<Bool b>`) = \value("<b>" == true);

default DBObject expr2obj(Expr e) { throw "Unsupported MongoDB restriction expression: <e>"; }

