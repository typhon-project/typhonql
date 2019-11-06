module lang::typhonql::Order

import lang::typhonml::Util;
import lang::typhonql::TDBC;
import lang::typhonql::Normalize;

import lang::typhonml::TyphonML;


import IO;
import Set;
import String;
import List;


/*

General (naive) compilation scheme:

Assume a Java map contains the results per entity of the back-end evaluations
 (either converted to uniform format, or natively)
 
Alternatively: they could be actual java variables of the native back-end type;
so a Resultset representing the set of entities returned from the SQL part.
The generated loop code could then iterate directly.

General: for each #dynamic binding E x, generate nested for loops
  for (Entity x: map.get("E")) {
    ...
       
       
Then in the innermost loop body:
 
SQL:
  generate java code to create a prepared statement, replacing refs to the #dynamic bindings
  with (named?) "?" marks and interpolate the arguments using the loop vars
  
  the sql in the prepared statement ignores the #ignored bindings and the #needed/#delayed
  expressions, but adds the local field refs in #needed expressions to the result set.
  
MongoDB
  generate Java code that creates the template BSON document, directly
  inserting the loop variables in designated places


*/



syntax Binding
  = "#dynamic" "(" Binding ")" // entity binding comes from previous round
  | "#ignored" "(" Binding ")" // entity results are produced later
      // if a binding is #ignored, all refs in expressions to it should be #delayed or #needed
  ;

syntax Expr
  = "#done" "(" Expr ")" // has been already evaluated in previous round
  | "#needed" "(" Expr ")" // evaluated later, but need result from this round
  | "#delayed" "(" Expr ")" // evaluated later completely
  // unannotated means: evaluate in current round
  ;
  


alias WPlace = tuple[Place place, int weight];


data RelativeOrder = before() | same() | after();


Place placeOf(str entity, Schema s) = p
  when <Place p, entity> <- s.placement;

RelativeOrder compare(str entity, Place p, list[Place] order, Schema s) 
  = compare(placeOf(entity, s), p, order);
  
RelativeOrder compare(Place p1, Place p2, list[Place] order) {
  int idx1 = indexOf(order, p1);
  int idx2 = indexOf(order, p2);
  if (idx1 < idx2) {
    return before();
  }
  else if (idx1 > idx2) {
    return after();
  }
  return same();
} 


bool isAfter(str entity, Place p, list[Place] order, Schema s) 
  = indexOf(p2) > indexOf(p, order)
  when <Place p2, entity> <- s.placement;

@doc{Restricting a query to a specific db places consists of 
annotating the query's bindings (`Entity x`) and the result/where 
expressions. The annotations indicate if expression evaluation 
should be delayed or not to later phases, and whether entity sets
are only available dynamically.}
Request restrict(req:(Request)`<Query q>`, Place p, list[Place] order, Schema s) {
  Env env = queryEnv(q);
  
  RelativeOrder entityOrder(str e) = compare(e, p, order, s);
  
  set[RelativeOrder] orders(Expr e) = { entityOrder(env["<x>"]) | /VId x := e }; 
  
  bool allBefore(Expr e) = orders(e) == {before()};
  
  bool allAfter(Expr e) = orders(e) == {after()};
  
  bool someAfter(Expr e) = after() in orders(e);
  
  Expr orderExpr(Expr e) {
    if (allAfter(e)) {
      return (Expr)`#delayed(<Expr e>)`;
    }
    if (someAfter(e)) {
      return (Expr)`#needed(<Expr e>)`;
    }
    if (allBefore(e)) {
      return (Expr)`#done(<Expr e>)`;
    }
    return e; // all local to this round
  }
  
  req = top-down-break visit (req) {
    case (Binding)`<EId e> <VId x>` => (Binding)`#dynamic(<EId e> <VId x>)`
      when entityOrder("<e>") == before()

    case (Binding)`<EId e> <VId x>` => (Binding)`#ignored(<EId e> <VId x>)`
      when entityOrder("<e>") == after()
      
    case (Result)`<Expr e>` => (Result)`<Expr e2>`
      when Expr e2 := orderExpr(e)  
      
    case Where wh: { 
      // map over the expressions
      insert top-down-break visit (wh) {
        case Expr e => orderExpr(e)
      }
    }  
      
     
  } 
  
  return req;
  
}


@doc{Ordering places uses the `filterWeight` value of the query for a place
to obtain an ordering of partitioning and query execution.
Higher filterWeight means execute earlier.
}
list[Place] orderPlaces(Request req, Schema s) {
  list[WPlace] weights = [ <p, filterWeight(req, p, s)> | Place p <- s.placement<0> ];
  
  list[WPlace] sortedWeights = sort(weights, bool(WPlace w1, WPlace w2) {
    return w1.weight > w2.weight; 
  });
  
  return sortedWeights<place>; 
}

@doc{Filterweight assigns a number to a query indicating how often an entity
is used in an where-expression, that is from a certain database.
A weight of 0 indicates that no filtering is done. The higher the
number the more "constrained" and hence smaller the result-set is
expected to be, so we use this to order query execution. 

If two or more db places obtain the same weight, the ordering
is supposed to be arbitrary. 
}
int filterWeight((Request)`<Query q>`, Place p, Schema s) {
  Env env = queryEnv(q);
  return ( 0 | it + filterWeight(e, p, env, s) | /Where w := q, Expr e <- w.clauses );
}

int filterWeight(Expr e, Place p, map[str, str] env, Schema s)
  = ( 0 | it + 1 | /VId x := e, <p, env["<x>"]> in s.placement ); 
  

  
void tests() {

 s = schema({
    <"Person", zero_many(), "reviews", "user", \one(), "Review", true>,
    <"Review", \one(), "user", "reviews", \zero_many(), "Person", false>,
    <"Review", \one(), "comment", "owner", \zero_many(), "Comment", true>,
    <"Comment", zero_many(), "replies", "owner", \zero_many(), "Comment", true>
  }, {
    <"Person", "name", "String">,
    <"Person", "age", "int">,
    <"Review", "text", "String">,
    <"Comment", "contents", "String">,
    <"Reply", "reply", "String">
  },
  placement = {
    <<sql(), "Inventory">, "Person">,
    <<mongodb(), "Reviews">, "Review">,
    <<mongodb(), "Reviews">, "Comment">
  } 
  );
  
  
  println("\n\n#####");
  println("## ordered weights");
  q = (Request)`from Person p, Review r select r.text where p.name == "Pablo", r.user == p`;  
  println("Ordering <q>");
  order = orderPlaces(q, s);
  println("ORDER = <order>");
  for (Place p <- order) {
    println("weight for <p>: <filterWeight(q, p, s)>");
    println("restrict:\n\t\t <restrict(q, p, order, s)>\n\n");
  }
  
  
  println("\n\n#####");
  println("## equal weights");
  //q = (Request)`from Product p, Review r select r.id where r.product == p, r.id == "bla", p.name == "Radio"`;
  q = (Request)`from Person p, Review r select r where p.name == r.text`;  
    
  println("Ordering <q>");
  order = orderPlaces(q, s);
  println("ORDER = <order>");
  for (Place p <- order) {
    println("weight for <p>: <filterWeight(q, p, s)>"); 
    println("restrict:\n\t\t <restrict(q, p, order, s)>\n\n");
  }
  
  
  
  println("\n\n#####");
  println("## after normalization");
  q = (Request)`from Person p, Review r select r.comment.replies.reply where r.user.age \> 10, r.user.name == "Pablo"`;
  println("ORIGINAL: <q>");
  q = expandNavigation(q, s);
  println("NORMALIZED: <q>");
    
  println("Ordering <q>");
  order = orderPlaces(q, s);
  println("ORDER = <order>");
  for (Place p <- order) {
    println("weight for <p>: <filterWeight(q, p, s)>"); 
    println("restrict:\n\t\t <restrict(q, p, order, s)>\n\n");
  } 
  
  
  
}
  