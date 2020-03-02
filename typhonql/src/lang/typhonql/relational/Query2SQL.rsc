module lang::typhonql::relational::Query2SQL

import lang::typhonql::TDBC;
import lang::typhonql::Normalize;
import lang::typhonql::Order;
import lang::typhonql::Script;
import lang::typhonql::Session;
import lang::typhonql::relational::SQL;
import lang::typhonql::relational::SQL2Text;
import lang::typhonql::relational::Util;


import lang::typhonml::TyphonML;
import lang::typhonml::Util;


import IO;
import String;

/*

to get null, instead of empty result sets, do the following for refs/containments

select `User.name`, `Review.user-User.reviews`.`Review.user`  
from User left outer join `Review.user-User.reviews` on `User.@id` = `Review.user-User.reviews`.`User.reviews`;

for multiples

select 
  `User.name`, 
  `Review.user-User.reviews`.`Review.user`, 
  `Biography.user-User.biography`.`Biography.user`
from 
  User left outer join 
   `Review.user-User.reviews` on `User.@id` = `Review.user-User.reviews`.`User.reviews`  left outer join
      `Biography.user-User.biography` on `User.@id` = `Biography.user-User.biography`.`User.biography`;


With names:

select 
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
      void(SQLExpr) addWhere,
      void(As) addFrom,
      void(SQLExpr) addResult,
      void(str, Param) addParam,
      Schema schema,
      Env env,
      set[str] dyns,
      int() vars,
      Place place
   ];


tuple[SQLStat, Bindings] compile2sql((Request)`<Query q>`, Schema s, Place p)
  = select2sql(q, s, p);

tuple[SQLStat, Bindings] select2sql((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs>`, Schema s, Place p) 
  = select2sql((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where true`, s, p);

/*

Steps to compile to SQL

- add the results to the SQL results after select except if #delayed or #done
- add the bindings to the SQL from clause with "as" except if #dynamic or #ignored
- add the required (junction) tables from relation navigation to the select clause
- add to the result the expressions used in #needed expressions
- translate refs to #dynamic entities to named placeholders, put the expression itself into params
- translate where clauses to sql where clause, possibly using junction tables, skip #done/#needed/#delayed


*/
tuple[SQLStat, Bindings] select2sql((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ ws>`
  , Schema s, Place p) {

  SQLStat q = select([], [], [where([])]);
  
  void addWhere(SQLExpr e) {
    // println("ADDING where clause: <pp(e)>");
    q.clauses[0].exprs += [e];
  }
  
  void addFrom(As as) {
    // println("ADDING table: <pp(as)>");
    q.tables += [as];
  }
  
  void addResult(SQLExpr e) {
    // println("ADDING result: <pp(e)>");
    q.exprs += [e];
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
    println("##### record results");
    visit (e) {
      case x:(Expr)`<VId y>`: {
         println("##### record results: var <y>");
    
         if (str ent := env["<y>"], <p, ent> <- ctx.schema.placement) {
           addResult(named(expr2sql(x, ctx), "<y>.<ent>.@id"));
           for (<ent, str a, str _> <- ctx.schema.attrs) {
             Id f = [Id]a;
             addResult(named(expr2sql((Expr)`<VId y>.<Id f>`, ctx), "<y>.<ent>.<f>"));
           }
         }
       }
      case x:(Expr)`<VId y>.@id`: {
         println("##### record results: var <y>.@id");
    
         if (str ent := env["<y>"], <p, ent> <- ctx.schema.placement) {
           addResult(named(expr2sql(x, ctx), "<y>.<ent>.@id"));
         }
      }
      case x:(Expr)`<VId y>.<Id f>`: {
         println("##### record results: <y>.<f>");
    
         if (str ent := env["<y>"], <p, ent> <- ctx.schema.placement) {
           addResult(named(expr2sql(x, ctx), "<y>.<ent>.<f>"));
           // todo: should be in Normalize
           idExpr = named(expr2sql((Expr)`<VId y>.@id`, ctx), "<y>.<ent>.@id");
           if (idExpr notin q.exprs) {
             addResult(idExpr);
           }
         }
      }
    }
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
        //addResult(expr2sql(e, ctx));
    }
  }

  for ((Binding)`<EId e> <VId x>` <- bs) {
    // skipping #dynamic / #ignored
    addFrom(as(tableName("<e>"), "<x>"));
  }
  
  for (Expr e <- ws) {
    switch (e) {
      case (Expr)`#needed(<Expr x>)`:
        recordResults(x);
      case (Expr)`#done(<Expr _>)`: ;
      case (Expr)`#delayed(<Expr _>)`: ;
      default: 
        addWhere(expr2sql(e, ctx));
    }
  }
  
  // println("PARAMS: <params>");
  return <q, params>;
}



str varForTarget(Id f, int i) = "<f>$<i>";

str varForJunction(Id f, int i) = "junction_<f>$<i>";


SQLExpr expr2sql(e:(Expr)`<VId x>`, Ctx ctx)
  = expr2sql((Expr)`<VId x>.@id`, ctx);


SQLExpr expr2sql(e:(Expr)`<VId x>.@id`, Ctx ctx) {
  if ("<x>" in ctx.dyns, str ent := ctx.env["<x>"], <Place p, ent> <- ctx.schema.placement) {
    str token = "<x>_<ctx.vars()>";
    ctx.addParam(token, field(p.name, "<x>", ctx.env["<x>"], "@id"));
    return SQLExpr::placeholder(name=token);
  }
  str entity = ctx.env["<x>"];
  return column("<x>", typhonId(entity));
}
  
// only one level of navigation because of normalization
SQLExpr expr2sql(e:(Expr)`<VId x>.<Id f>`, Ctx ctx) {
  // println("TRANSLATING: <e>");
  str entity = ctx.env["<x>"];
  str role = "<f>"; 

  if ("<x>" in ctx.dyns, str ent := ctx.env["<x>"], <Place p, ent> <- ctx.schema.placement) {
    str token = "<x>_<f>_<ctx.vars()>";
    ctx.addParam(token, field(p.name, "<x>", ctx.env["<x>"], "<f>"));
    return SQLExpr::placeholder(name=token);
  }

  
  if (<entity, _, role, str toRole, _, str to, true> <- ctx.schema.rels, placeOf(to, ctx.schema) == ctx.place) {
    // println("# local containment <entity> -<role>/<toRole>-\> <to>");
    str tbl1 = "<x>";
    str tbl2 = varForTarget(f, ctx.vars()); // introduce a new table alias
    ctx.addFrom(as(tableName(to), tbl2));
    ctx.addWhere(equ(column(tbl2, fkName(entity, to, toRole)), column(tbl1, typhonId(entity))));
    
    // the value is of this expression is the id column of the child table
    // provided that its parent is the table representing x 
    return column(tbl2, typhonId(to));
  }
  else if (<entity, _, role, str toRole, _, str to, _> <- ctx.schema.rels) {
  	println("# xref, or external containment: <entity> -<role>/<toRole>-\> <to> (`<e>`)  ");
    tbl = varForJunction(f, ctx.vars());
  	
  	ctx.addFrom(as(junctionTableName(entity, role, to, toRole), tbl));
  	
  	// add a where to link x to the junction table pointing to `to`
  	ctx.addWhere(equ(column(tbl, junctionFkName(entity, role)), column("<x>", typhonId(entity))));
  	
  	// return the column of the target
  	return column(tbl, junctionFkName(to, toRole));
  }
  else if (<entity, role, _> <- ctx.schema.attrs) { 
    // println("# an attribute");
    return column("<x>", columnName(role, entity));
  }
  else {
    throw "Unsupported navigation <entity>.<role>";
  }
}  
  

SQLExpr expr2sql((Expr)`?`, Ctx ctx) = placeholder();

SQLExpr expr2sql((Expr)`<Int i>`, Ctx ctx) = lit(integer(toInt("<i>")));

SQLExpr expr2sql((Expr)`<Real r>`, Ctx ctx) = lit(decimal(toReal("<r>")));

SQLExpr expr2sql((Expr)`<Str s>`, Ctx ctx) = lit(text("<s>"[1..-1]));

SQLExpr expr2sql((Expr)`<DateTime d>`, Ctx ctx) = lit(dateTime(readTextValueString(#datetime, "<d>")));

SQLExpr expr2sql((Expr)`<UUID u>`, Ctx ctx) = lit(text("<u>"[1..]));

SQLExpr expr2sql((Expr)`true`, Ctx ctx) = lit(boolean(true));

SQLExpr expr2sql((Expr)`false`, Ctx ctx) = lit(boolean(false));

SQLExpr expr2sql((Expr)`(<Expr e>)`, Ctx ctx) = expr2sql(e, ctx);

SQLExpr expr2sql((Expr)`null`, Ctx ctx) = lit(null());

SQLExpr expr2sql((Expr)`+<Expr e>`, Ctx ctx) = pos(expr2sql(e, ctx));

SQLExpr expr2sql((Expr)`-<Expr e>`, Ctx ctx) = neg(expr2sql(e, ctx));

SQLExpr expr2sql((Expr)`!<Expr e>`, Ctx ctx) = not(expr2sql(e, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> * <Expr rhs>`, Ctx ctx) 
  = mul(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> / <Expr rhs>`, Ctx ctx) 
  = div(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> + <Expr rhs>`, Ctx ctx) 
  = add(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> - <Expr rhs>`, Ctx ctx) 
  = sub(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> == <Expr rhs>`, Ctx ctx) 
  = equ(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> != <Expr rhs>`, Ctx ctx) 
  = neq(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> \>= <Expr rhs>`, Ctx ctx) 
  = geq(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> \<= <Expr rhs>`, Ctx ctx) 
  = leq(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> \> <Expr rhs>`, Ctx ctx) 
  = gt(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> \< <Expr rhs>`, Ctx ctx) 
  = lt(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> like <Expr rhs>`, Ctx ctx) 
  = like(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> && <Expr rhs>`, Ctx ctx) 
  = and(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> || <Expr rhs>`, Ctx ctx) 
  = or(expr2sql(lhs, ctx), expr2sql(rhs, ctx));


default SQLExpr expr2sql(Expr e, Ctx _) { throw "Unsupported expression: <e>"; }



/*


from Person p select p.name where p.name == "Pablo"
select p.`Person.name` from Person as  p where p.`Person.name` = 'Pablo' 


// person owns one review locally
from Person p, Review r select r.text where p.review == r

select r.`Review.text` from Person as `p`, Review `r`
where `r`.`Review.user` = `p`.`Person.@id` // reversed because SQL

// person owns one review locally, but query uses inverse
from Person p, Review r select r.text where r.user == p

select r.`Review.text` from Person as `p`, Review `r`
where `r`.`Review.user` = `p`.`Person.@id`


*/




void smoke2sqlWithAllOnSameSQLDB() {
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
    <<sql(), "Inventory">, "Review">,
    <<sql(), "Inventory">, "Comment">
  } 
  );
  
  return smoke2sql(s);
}

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


void smoke2sql(Schema s) {
  
  println("\n\n#####");
  println("## ordered weights");
  Request q = (Request)`from Person p, Review r select r.text where p.name == "Pablo", p.reviews == r`;  
  println("Ordering <q>");
  order = orderPlaces(q, s);
  println("ORDER = <order>");
  for (Place p <- order, p.db == sql()) {
    println("\n\t#### Translation of <restrict(q, p, order, s)>");
    <stat, params> = compile2sql(restrict(q, p, order, s), s, p); 
    println(pp(stat));
  }
  
  
  //println("\n\n#####");
  //println("## equal weights");
  ////q = (Request)`from Product p, Review r select r.id where r.product == p, r.id == "bla", p.name == "Radio"`;
  //q = (Request)`from Person p, Review r select r where p.name == r.text`;  
  //  
  //println("Ordering <q>");
  //order = orderPlaces(q, s);
  //println("ORDER = <order>");
  //for (Place p <- order, p.db == sql()) {
  //  println("weight for <p>: <filterWeight(q, p, s)>"); 
  //  println("restrict:\n\t\t <restrict(q, p, order, s)>\n\n");
  //  println(pp(compile2sql(restrict(q, p, order, s), s, p)));
  //}
  //
  //
  //
  //println("\n\n#####");
  //println("## after normalization");
  //q = (Request)`from Person p, Review r select r.comment.replies.reply where r.user.age \> 10, r.user.name == "Pablo"`;
  //println("ORIGINAL: <q>");
  //q = expandNavigation(q, s);
  //println("NORMALIZED: <q>");
  //  
  //println("Ordering <q>");
  //order = orderPlaces(q, s);
  //println("ORDER = <order>");
  //for (Place p <- order, p.db == sql()) {
  //  println("weight for <p>: <filterWeight(q, p, s)>"); 
  //  println("restrict:\n\t\t <restrict(q, p, order, s)>\n\n");
  //  println(pp(compile2sql(restrict(q, p, order, s), s, p)));
  //} 
  
  
  
}
