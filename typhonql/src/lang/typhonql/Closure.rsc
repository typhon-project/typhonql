module lang::typhonql::Closure


import lang::typhonql::TDBC;
import lang::typhonql::Partition;

import lang::typhonml::Util;

/*

Compute the "database closure" of a TyphonQL query. It computes all database
placements that are "hit" by the query.

*/


rel[Place, str] closure(q:(Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ es>`, Schema s) {
  map[str, str] env = ( "<x>": "<e>"  | (Binding)`<EId e> <VId x>` <- bs );
  
  
  rel[Place, str] result = { <p, e> | str e <- env<1>, <Place p, e> <- s.placement };
  
  
  result += { *dbPlacements(e, env, s) | (Result)`<Expr e>` <- rs };
  result += { *dbPlacements(e, env, s) | Expr e <- es };
  
  return result;
}

