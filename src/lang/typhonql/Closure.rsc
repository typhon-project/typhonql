module lang::typhonql::Closure


import lang::typhonql::TDBC;
import lang::typhonql::Partition;

import lang::typhonml::Util;


rel[Place, str] closure(q:(Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ es>`, Schema s) {
  map[str, str] env = ( "<x>": "<e>"  | (Binding)`<EId e> <VId x>` <- bs );
  rel[Place, str] result = {};
  
  result += { *dbPlacements(e, env, s) | (Result)`<Expr e>` <- rs };
  result += { *dbPlacements(e, env, s) | Expr e <- es };
  
  return result;
}

