module lang::typhonql::Order

import lang::typhonml::Util;
import lang::typhonql::TDBC;
import lang::typhonql::util::Objects;

import lang::typhonml::TyphonML;


import IO;
import Set;
import String;
import List;



syntax Binding
  = "#dynamic" "(" Binding ")"
  | "#ignored" "(" Binding ")"
  ;

syntax Expr
  = "#done" "(" Expr ")" // evaluated in previous round
  | "#needed" "(" Expr ")" // evaluated later, but need result from this round
  | "#delayed" "(" Expr ")" // evaluated later completely
  ;
  

alias Env = map[str var, str entity];

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

Request restrict(req:(Request)`<Query q>`, Place p, list[Place] order, Schema s) {
  Env env = queryEnv(q);
  
  /*
   * add result exprs for expressions from the current that are used in where clauses that are later
   */
  
  
  set[RelativeOrder] orders(Expr e) = { compare(env["<x>"], p, order, s) | /VId x := e }; 
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
    return e; // all local/same
  }
  
  req = top-down-break visit (req) {
    case (Binding)`<EId e> <VId x>` => (Binding)`#dynamic(<EId e> <VId x>)`
      when compare("<e>", p, order, s) == before()

    case (Binding)`<EId e> <VId x>` => (Binding)`#ignored(<EId e> <VId x>)`
      when compare("<e>", p, order, s) == after()
      
    case (Result)`<Expr e>` => (Result)`<Expr e2>`
      when Expr e2 := orderExpr(e)  
      
    case Where wh: { 
      // complicated way to map over the expressions
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
  

Env queryEnv(Query q) = ("<x>": "<e>" | (Binding)`<EId e> <VId x>` <- q.bindings );

  
void tests() {

  s = schema({
    <"Person", zero_many(), "reviews", "user", \one(), "Review", true>,
    <"Review", \one(), "user", "reviews", \zero_many(), "Person", false>
  }, {
    <"Person", "name", "String">,
    <"Review", "text", "String">
  },
  placement = {
    <<sql(), "Inventory">, "Person">,
    <<mongodb(), "Reviews">, "Review">
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
  
  
}
  