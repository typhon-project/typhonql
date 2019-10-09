module lang::typhonql::WorkingSet

import lang::typhonql::util::UUID;
import List;

alias WorkingSet
  = map[str entity, list[Entity] entities];


alias Entity
  = tuple[str name, str uuid, map[str, value] fields];


data Ref
  = null()
  | uuid(str id)
  ;

  
Entity toEntity(Entity e) = e;

default Entity toEntity(value v) = <"anonymous", makeUUID(), ("value": toWsValue(v))>;


// BRITTLE (need schema to actually interpret)
value toWsValue(str s) = uuid(s)
  when 
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/ := s;
    
default value toWsValue(value v) = v;
    
list[map[str, Entity]] toBindings(lrel[str, str] env, list[value] product) 
  = [ toMap(env, tuple2list(v)) | value v <- product ];  

map[str, Entity] toMap(lrel[str, str] env, list[value] vs) 
  = ( env[i][0]: e | int i <- [0..size(env)], Entity e := vs[i] );

list[value] tuple2list(<value v1>) = [v1];

list[value] tuple2list(<value v1, value v2>) = [v1, v2];

list[value] tuple2list(<value v1, value v2, value v3>) = [v1, v2, v3];

list[value] tuple2list(<value v1, value v2, value v3, value v4>) = [v1, v2, v3, v4];

list[value] tuple2list(<value v1, value v2, value v3, value v4, value v5>) = [v1, v2, v3, v4, v5];

default list[value] tuple2list(value v) {
  throw "Cannot convert <v> to list";
}
 


// value, because we don't know how wide the tuples are
list[value] bigProduct(lrel[str, str] env, WorkingSet ws) {
 // int i = 0;
 // str firstEntity = env[i][1];
 // while (firstEntity notin ws, i < size(env) - 1) {
 //    i += 1;
 //    firstEntity = env[i][1];
 // }
 // 
 // // Ugh this should be automatic somehow...
 // if (i == size(env) - 1, firstEntity notin ws) {
 //    return [];
 // }
 //
 
  for (<str _, str e> <- env) {
     if (e notin ws) {
       ws[e] = [];
     }
  }
 
  return ( tupleize(ws[env[0][1]])  | it join tupleize(ws[e]) | <str _, str e> <- env[1..], e in ws );
    
  
}


list[tuple[&T]] tupleize(list[&T] xs) = [ <x> | &T x <- xs ];
  