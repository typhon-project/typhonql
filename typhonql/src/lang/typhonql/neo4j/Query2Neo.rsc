module lang::typhonql::neo4j::Query2Neo

import lang::typhonql::TDBC;
import lang::typhonql::Normalize;
import lang::typhonql::Order;
import lang::typhonql::Script;
import lang::typhonql::Session;

import lang::typhonql::neo4j::Neo;
import lang::typhonql::neo4j::NeoUtil;
import lang::typhonql::neo4j::Neo2Text;

import lang::typhonml::TyphonML;
import lang::typhonml::Util;

import lang::typhonql::util::Log;

import IO;
import ValueIO;
import String;
import List;

/*

to get null, instead of empty result sets, do the following for refs/containments

match `User.name`, `Review.user-User.reviews`.`Review.user`  
from User left outer join `Review.user-User.reviews` on `User.@id` = `Review.user-User.reviews`.`User.reviews`;

for multiples

match 
  `User.name`, 
  `Review.user-User.reviews`.`Review.user`, 
  `Biography.user-User.biography`.`Biography.user`
from 
  User left outer join 
   `Review.user-User.reviews` on `User.@id` = `Review.user-User.reviews`.`User.reviews`  left outer join
      `Biography.user-User.biography` on `User.@id` = `Biography.user-User.biography`.`User.biography`;


With names:

match 
  u.`User.name`, 
  r.`Review.user`, 
  b.`Biography.user`  
from 
  User as u left outer join `Review.user-User.reviews` as r 
     on u.`User.@id` = r.`User.reviews` 
       left outer join `Biography.user-User.biography` as b 
         on u.`User.@id` = b.`User.biography`;

*/

alias Ctx
  = tuple[
      void(NeoExpr) addWhere,
      void(str, str) addFrom,
      //void(str, As, NeoExpr) addLeftOuterJoin,
      void(NeoExpr) addResult,
      void(str, Param) addParam,
      Schema schema,
      Env env,
      set[str] dyns,
      int() vars,
      Place place
   ];


tuple[NeoStat, Bindings] compile2neo((Request)`<Query q>`, Schema s, Place p, Log log = noLog)
  = select2neo(q, s, p, log = log);

tuple[NeoStat, Bindings] select2neo((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs>`, Schema s, Place p, Log log = noLog) 
  = select2neo((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where true`, s, p, log = log);

/*

Steps to compile to SQL

- add the results to the SQL results after match except if #delayed or #done
- add the bindings to the SQL from clause with "as" except if #dynamic or #ignored
- add the required (junction) tables from relation navigation to the match clause
- add to the result the expressions used in #needed expressions
- translate refs to #dynamic entities to named placeholders, put the expression itself into params
- translate where clauses to sql where clause, possibly using junction tables, skip #done/#needed/#delayed


*/
tuple[NeoStat, Bindings] select2neo((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ ws>`
  , Schema s, Place p, Log log = noLog) {

  NeoStat q = matchQuery(match([], [where([])], []));
  
  void addWhere(NeoExpr e) {
    // println("ADDING where clause: <pp(e)>");
    q.match.clauses[0].exprs += [e];
  }
  
  void addFrom(str var, str label) {
    // println("ADDING table: <pp(as)>");
    q.match.patterns += [pattern(nodePattern(var, label, []), [])];
  }
  
  void addResult(NeoExpr e) {
    // println("ADDING result: <pp(e)>");
    q.match.exprs += [e];
  }
  
  int _vars = -1;
  int vars() {
    return _vars += 1;
  }

  Bindings params = ();
  void addParam(str x, Param field) {
    params[x] = field;
  }

  Env env = (); 
  set[str] dyns = {};
  for (Binding b <- bs) {
    switch (b) {
      case (Binding)`<EId e> <VId x>`:
        env["<x>"] = "<e>";
      case (Binding)`#dynamic(<EId e> <VId x>)`: {
        env["<x>"] = "<e>";
        dyns += {"<x>"};
      }
      case (Binding)`#ignored(<EId e> <VId x>)`:
        env["<x>"] = "<e>";
    }
  }
  

  Ctx ctx = <
     addWhere,
     addFrom,
     addResult,
     addParam,
     s,
     env,
     dyns,
     vars,
     p>;

  
  void recordResults(Expr e) {
    log("##### record results");
    visit (e) {
      case x:(Expr)`<VId y>`: {
         log("##### record results: var <y>");
    
         if (str ent := env["<y>"], <p, ent> <- ctx.schema.placement) {
           addResult(named(expr2neo(x, ctx), "<y>.<ent>.@id"));
           for (<ent, str a, str _> <- ctx.schema.attrs) {
             Id f = [Id]a;
             addResult(named(expr2neo((Expr)`<VId y>.<Id f>`, ctx), "<y>.<ent>.<f>"));
           }
         }
       }
      case x:(Expr)`<VId y>.@id`: {
         log("##### record results: var <y>.@id");
    
         if (str ent := env["<y>"], <p, ent> <- ctx.schema.placement) {
           addResult(named(expr2neo(x, ctx), "<y>.<ent>.@id"));
         }
      }
      case x:(Expr)`<VId y>.<Id f>`: {
         log("##### record results: <y>.<f>");
    
         if (str ent := env["<y>"], <p, ent> <- ctx.schema.placement) {
           addResult(named(expr2neo(x, ctx), "<y>.<ent>.<f>"));
           // todo: should be in Normalize
           idExpr = named(expr2neo((Expr)`<VId y>.@id`, ctx), "<y>.<ent>.@id");
           if (idExpr notin q.match.exprs) {
             addResult(idExpr);
           }
         }
      }
    }
  }

  
  // NB: this needs to happen before adding
  // results, because "."-expressions in
  // results require tables for joining.
  for ((Binding)`<EId e> <VId x>` <- bs) {
    // skipping #dynamic / #ignored
    addFrom("<x>", "<e>");
  }

  for ((Result)`<Expr e>` <- rs) {
    switch (e) {
      case (Expr)`#done(<Expr x>)`: ;
      case (Expr)`#delayed(<Expr x>)`: ;
      case (Expr)`#needed(<Expr x>)`: 
        recordResults(x);
      default:
        // todo: allow arbitrary expressions if they have "as"
        recordResults(e);
        //addResult(expr2neo(e, ctx));
    }
  }

  for (Expr e <- ws) {
    switch (e) {
      case (Expr)`#needed(<Expr x>)`:
        recordResults(x);
      case (Expr)`#done(<Expr _>)`: ;
      case (Expr)`#delayed(<Expr _>)`: ;
      default: 
        addWhere(expr2neo(e, ctx));
    }
  }
  
  if (q.match.clauses[0].exprs == []) {
    q.match.clauses = [];
  }
  
  // println("PARAMS: <params>");
  return <q, params>;
}



str varForTarget(Id f, int i) = "<f>$<i>";

str varForJunction(Id f, int i) = "junction_<f>$<i>";


NeoExpr expr2neo(e:(Expr)`<VId x>`, Ctx ctx, Log log = noLog)
  = expr2neo((Expr)`<VId x>.@id`, ctx);


NeoExpr expr2neo(e:(Expr)`<VId x>.@id`, Ctx ctx, Log log = noLog) {
  if ("<x>" in ctx.dyns, str ent := ctx.env["<x>"], <Place p, ent> <- ctx.schema.placement) {
    str token = "<x>_<ctx.vars()>";
    ctx.addParam(token, field(p.name, "<x>", ctx.env["<x>"], "@id"));
    return NeoExpr::placeholder(name=token);
  }
  str entity = ctx.env["<x>"];
  return property("<x>", typhonId(entity));
}
  
// only one level of navigation because of normalization
NeoExpr expr2neo(e:(Expr)`<VId x>.<Id f>`, Ctx ctx, Log log = noLog) {
  log("TRANSLATING: <e>");
  str entity = ctx.env["<x>"];
  str role = "<f>"; 

  if ("<x>" in ctx.dyns, str ent := ctx.env["<x>"], <Place p, ent> <- ctx.schema.placement) {
    str token = "<x>_<f>_<ctx.vars()>";
    ctx.addParam(token, field(p.name, "<x>", ctx.env["<x>"], "<f>"));
    return NeoExpr::placeholder(name=token);
  }

  
  if (<entity, _, role, str toRole, _, str to, true> <- ctx.schema.rels, placeOf(to, ctx.schema) == ctx.place) {
    log("########### local containment <entity> -<role>/<toRole>-\> <to>");
    str tbl1 = "<x>";
    str tbl2 = varForTarget(f, ctx.vars()); // introduce a new table alias
    ctx.addLeftOuterJoin(tbl1,
       as(tableName(to), tbl2),
       equ(column(tbl2, fkName(entity, to, toRole)), column(tbl1, typhonId(entity))));
       
    // the value is of this expression is the id column of the child table
    // provided that its parent is the table representing x 
    return column(tbl2, typhonId(to));
  }
  else if (<str parent, _, str parentRole, role, _, entity, true> <- ctx.schema.rels, placeOf(parent, ctx.schema) == ctx.place) {
    log("########### local (reverse) containment <parent> -<parentRole>/<role>-\> <entity>");
    str tbl1 = "<x>";
    return column(tbl1, fkName(parent, entity, role));
  }
  else if (<entity, _, role, str toRole, _, str to, _> <- ctx.schema.rels) {
  	log("######### xref, or external containment: <entity> -<role>/<toRole>-\> <to> (`<e>`)  ");
  	tbl1 = "<x>";
    tbl2 = varForJunction(f, ctx.vars());

    ctx.addLeftOuterJoin(tbl1,  	
  	  as(junctionTableName(entity, role, to, toRole), tbl2),
  	  equ(column(tbl2, junctionFkName(entity, role)), column(tbl1, typhonId(entity))));
  	
  	// return the column of the target
  	return column(tbl2, junctionFkName(to, toRole));
  }
  else if (<entity, role, str atype> <- ctx.schema.attrs) { 
    log("# an attribute <entity>.<role>");
    normalAccess = property("<x>", nodeName(entity, role));
    if (atype in {"point", "polygon"}) {
        return fun("ST_AsWKB", [normalAccess]);
    }
    return normalAccess;
  }
  else {
    throw "Unsupported navigation <entity> <x>.<role>";
  }
}  

str nodeName(str role, str entity) = "<role>.<entity>";

NeoExpr expr2neo((Expr)`?`, Ctx ctx, Log log = noLog) = placeholder();

NeoExpr expr2neo((Expr)`<Int i>`, Ctx ctx, Log log = noLog) = lit(integer(toInt("<i>")));

NeoExpr expr2neo((Expr)`<Real r>`, Ctx ctx, Log log = noLog) = lit(decimal(toReal("<r>")));

NeoExpr expr2neo((Expr)`<Str s>`, Ctx ctx, Log log = noLog) = lit(text("<s>"[1..-1]));

NeoExpr expr2neo((Expr)`<DateAndTime d>`, Ctx ctx, Log log = noLog) = lit(dateTime(readTextValueString(#datetime, "<d>")));

NeoExpr expr2neo((Expr)`<JustDate d>`, Ctx ctx, Log log = noLog) = lit(date(readTextValueString(#datetime, "<d>")));

NeoExpr expr2neo((Expr)`#point(<Real x> <Real y>)`, Ctx ctx, Log log = noLog) = lit(point(toReal("<x>"), toReal("<y>")));

NeoExpr expr2neo((Expr)`#polygon(<{Segment ","}* segments>)`, Ctx ctx, Log log = noLog) 
    = lit(polygon([ [<toReal("<x>"), toReal("<y>")> | (XY)`<Real x> <Real y>` <- s.points] | s <- segments]));


NeoExpr expr2neo((Expr)`false`, Ctx ctx, Log log = noLog) = lit(boolean(false));

NeoExpr expr2neo((Expr)`<UUID u>`, Ctx ctx, Log log = noLog) = lit(text("<u>"[1..]));

NeoExpr expr2neo((Expr)`true`, Ctx ctx, Log log = noLog) = lit(boolean(true));

NeoExpr expr2neo((Expr)`false`, Ctx ctx, Log log = noLog) = lit(boolean(false));

NeoExpr expr2neo((Expr)`(<Expr e>)`, Ctx ctx, Log log = noLog) = expr2neo(e, ctx);

NeoExpr expr2neo((Expr)`null`, Ctx ctx, Log log = noLog) = lit(null());

NeoExpr expr2neo((Expr)`+<Expr e>`, Ctx ctx, Log log = noLog) = pos(expr2neo(e, ctx));

NeoExpr expr2neo((Expr)`-<Expr e>`, Ctx ctx, Log log = noLog) = neg(expr2neo(e, ctx));

NeoExpr expr2neo((Expr)`!<Expr e>`, Ctx ctx, Log log = noLog) = not(expr2neo(e, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> * <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = mul(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> / <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = div(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> + <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = add(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> - <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = sub(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> == <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = equ(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> != <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = neq(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> \>= <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = geq(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> \<= <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = leq(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> \> <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = gt(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> \< <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = lt(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> like <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = like(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> && <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = and(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> || <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = or(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr removeWKB(fun("ST_AsWKB", [a])) = a;
default NeoExpr removeWKB(NeoExpr other) = other;

NeoExpr expr2neo((Expr)`<Expr lhs> & <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = equ(fun("ST_Intersects", [removeWKB(expr2neo(lhs, ctx)), removeWKB(expr2neo(rhs, ctx))]), lit(integer(1)));

NeoExpr expr2neo((Expr)`<Expr lhs> in <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = equ(fun("ST_Within", [removeWKB(expr2neo(lhs, ctx)), removeWKB(expr2neo(rhs, ctx))]), lit(integer(1)));

NeoExpr expr2neo((Expr)`distance(<Expr from>, <Expr to>)`, Ctx ctx, Log log = noLog)
  = fun("ST_Distance", [removeWKB(expr2neo(from, ctx)), removeWKB(expr2neo(from, ctx))]);

default NeoExpr expr2neo(Expr e, Ctx _) { throw "Unsupported expression: <e>"; }



/*


from Person p match p.name where p.name == "Pablo"
match p.`Person.name` from Person as  p where p.`Person.name` = 'Pablo' 


// person owns one review locally
from Person p, Review r match r.text where p.review == r

match r.`Review.text` from Person as `p`, Review `r`
where `r`.`Review.user` = `p`.`Person.@id` // reversed because SQL

// person owns one review locally, but query uses inverse
from Person p, Review r match r.text where r.user == p

match r.`Review.text` from Person as `p`, Review `r`
where `r`.`Review.user` = `p`.`Person.@id`


*/




void smoke2neoSelectWithAllOnSameNeoDB() {
  s = schema({
    <"Company", \zero_many(), "locations", "companies", \zero_many(), "City", false>
  }, {
    <"City", "name", "String">,
    <"City", "population", "int">,
    <"Company", "name", "String">,
    <"Company", "employees", "int">
  },
  placement = {
    <<neo4j(), "Companies">, "Company">,
    <<neo4j(), "Companies">, "City">
  } 
  );
  
  return smoke2neo(s);
}
/*
void smoke2sqlWithAllOnDifferentSQLDB() {
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
    <<sql(), "Reviews">, "Review">,
    <<sql(), "Reviews">, "Comment">
  } 
  );
  
  return smoke2sql(s);
}

*/
void smoke2neo(Schema s) {
  
  println("\n\n#####");
  println("## ordered weights");
  Request q = (Request)`from City c select c.name where c.name == "Atlanta"`;  
  println("Ordering <q>");
  order = orderPlaces(q, s);
  println("ORDER = <order>");
  for (Place p <- order, p.db == neo4j()) {
    println("\n\t#### Translation of <restrict(q, p, order, s)>");
   	<stat, params> = compile2neo(restrict(q, p, order, s), s, p); 
    println(stat);
    
    println(pp(stat));
  }
  
}
