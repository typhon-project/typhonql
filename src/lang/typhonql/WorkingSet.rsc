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
    /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/ := s;
    
default value toWsValue(value v) = v;
    
    

WorkingSet exampleWorkingSet() =
 ( 
   "Product": [
      <"Product", "#abcd", ("name": "TV", "count": 10)>,
      <"Product", "#defg", ("name": "CD Player", "count": 120)>
   ],
   "Person": [
      <"Person", "#hijk", ("name": "Jurgen", "age": 42)>,
      <"Person", "#lmno", ("name": "Thijs", "age": 41)>,
      <"Person", "#pqrs", ("name": "Paul", "age": 67)>
   ]
 );


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
list[value] bigProduct(lrel[str, str] env, WorkingSet ws) 
  = ( tupleize(ws[env[0][1]])  | it join tupleize(ws[e]) | <str _, str e> <- env[1..] );


list[tuple[&T]] tupleize(list[&T] xs) = [ <x> | &T x <- xs ];
  