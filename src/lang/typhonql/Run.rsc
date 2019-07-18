module lang::typhonql::Run

import lang::typhonql::Bridge;
import lang::typhonql::WorkingSet;
import lang::typhonml::Util;
import lang::typhonql::Partition;
import lang::typhonql::TDBC;

import lang::typhonql::relational::SQL;
import lang::typhonql::relational::SQL2Text;

import List;



value run((Request)`delete <EId e> <VId x> where <{Expr ","}+ es>`, Schema s) {
  Request selectReq = (Request)`from <EId e> <VId x> select <VId x>.@id where <{Expr ","}+ es>`;
  Partitioning part = partition(selectReq, s);
  
  WorkingSet ws = runPartitionedQueries(part, s);
  
  assert size(ws<0>) == 1: "multiple or zero entity types returned from select implied by delete";
  
  if (str entity <- ws, <Place p, entity> <- s.placement) {
    entities = ws[entity];
    for (<entity, str uuid, _> <- ws[entity]) {
      runDeleteById(p, entity, uuid);
    }
  } 

}


value run(q:(Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ es>`, Schema s) {
  Partitioning part = partition(q, s);
  WorkingSet ws = runPartitionedQueries(part, s);
  
  WorkingSet result = ();
  
  lrel[str, str] orderedEnv = [ <"<x>", "<e>">  | (Binding)`<EId e> <VId x>` <- bs ];
  
  map[str, str] env = ( "<x>": "<e>"  | (Binding)`<EId e> <VId x>` <- bs );
  
  for (Expr e <- es, !isLocal(e, env, s)) {
    // we need bigProduct here... using join
    ;
  }
  
}

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


// value, because we don't know how wide the tuples are
list[value] bigProduct(lrel[str, str] env, WorkingSet ws) 
  = ( tupleize(ws[env[0][1]])  | it join tupleize(ws[e]) | <str _, str e> <- env[1..] );


list[tuple[&T]] tupleize(list[&T] xs) = [ <x> | &T x <- xs ];

WorkingSet runPartitionedQueries(Partitioning part, Schema s) 
  = ( () | it + runNativeQuery(p, q, s) | <Place p, Request q> <- part );


/*
These functions are the "interface" that needs to be implemented for every backend.
*/

WorkingSet runNativeQuery(<mongodb(), str db>, Request q, Schema s) {

}

WorkingSet runNativeQuery(<sql(), str db>, Request q, Schema s) {

}


void runDeleteById(<mongodb(), str db>, str entity, str uuid) {
  deleteOne(db, entity, ("_id": uuid));
}

void runDeleteById(<sql(), str db>, str entity, str uuid) {
  str tbl = tableName("<entity>");
  SQLStat stat = delete(tbl, [where([equ(column(tbl, typhonId(entity)), lit(text(uuid)))])]);
  execute(db, entity, pp(stat));
}
