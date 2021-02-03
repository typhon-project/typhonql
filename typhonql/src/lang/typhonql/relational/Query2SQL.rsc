/********************************************************************************
* Copyright (c) 2018-2020 CWI & Swat.engineering 
*
* This program and the accompanying materials are made available under the
* terms of the Eclipse Public License 2.0 which is available at
* http://www.eclipse.org/legal/epl-2.0.
*
* This Source Code may also be made available under the following Secondary
* Licenses when the conditions for such availability set forth in the Eclipse
* Public License, v. 2.0 are satisfied: GNU General Public License, version 2
* with the GNU Classpath Exception which is
* available at https://www.gnu.org/software/classpath/license.html.
*
* SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0
********************************************************************************/

module lang::typhonql::relational::Query2SQL

import lang::typhonql::TDBC;
import lang::typhonql::Normalize;
import lang::typhonql::Order;
import lang::typhonql::Script;
import lang::typhonql::Session;

import lang::typhonql::Query2Script;

import lang::typhonql::relational::SQL;
import lang::typhonql::relational::SQL2Text;
import lang::typhonql::relational::Util;


import lang::typhonml::TyphonML;
import lang::typhonml::Util;

import lang::typhonql::util::Log;
import lang::typhonql::util::Strings;
import lang::typhonql::util::Dates;

import IO;
import ValueIO;
import String;
import List;

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


alias SQLAggWeaver = SQLStat(SQLStat, Ctx);

SQLStat noAgg(SQLStat q, Ctx ctx) = q; 

SQLStat weaveAggregation(
  agg:(Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> 
           'where true <Agg* aggs>`, SQLStat query, Ctx ctx) {
           
  list[Result] rLst = [ r | Result r <- rs ];
  
  Env env = queryEnv(bs);
  
  // we cannot use  expr2sql, because it creates new
  // variables of non-existing tables (e.g. inventory$1),
  // so we append based on existing sql exprs that
  // we find by position (we need the original because
  // of the aliasing)
  for ((Result)`<VId f>(<Expr arg>) as <VId x>` <- rs) {
      // because of side-effects of expr2sql we cannot as of now compare
      // the actual expressions, so we compare the names given to the results (using "as")
      // to find the original expression.
      if (SQLExpr org <- query.exprs, expr2sql(arg, ctx).name == org.arg.name) {
        Path path = exp2path(arg, env, ctx.schema)[0];
        str theAlias = "<path.var>.<path.entityType>.<x>";
        ctx.addAggAlias("<x>", SQLExpr::var(theAlias)); 
      
        // note: append
        query.exprs += [named(fun(agg2sql(f), [org is named ? org.arg : org])
          , theAlias)];
       }
  }
  
  
  //alias Path = tuple[str dbName, str var, str entityType, list[str] path];
  
  for (Agg agg <- aggs) {
    switch (agg) {
      case (Agg)`group null`: 
        ;
      case (Agg)`group <{Expr ","}+ gs>`:
        query.clauses += [ groupBy([ expr2sql(g, ctx) | Expr g <- gs ]) ];
  	  case (Agg)`having <{Expr ","}+ hs>`:
        query.clauses += [ having([ expr2sql(h, ctx) | Expr h <- hs ]) ];
  	  case (Agg)`order <{Expr ","}+ os> <Dir dir>`:
        query.clauses += [ orderBy([ expr2sql(or, ctx) | Expr or <- os ], dir2dir(dir)) ];
    }
  }
  
  // limit etc should be at the end in SQL.
  for (Agg agg <- aggs) {
    switch (agg) {
      case (Agg)`limit <Expr l>`:
  	    query.clauses += [ limit(expr2sql(l, ctx)) ];
  	  case (Agg)`offset <Expr n>`:
  	    query.clauses += [ offset(expr2sql(n, ctx)) ];
    }
  }
  
  return query;
}

lang::typhonql::relational::SQL::Dir dir2dir((Dir)``) = asc();
lang::typhonql::relational::SQL::Dir dir2dir((Dir)`asc`) = asc();
lang::typhonql::relational::SQL::Dir dir2dir((Dir)`desc`) = desc();


str agg2sql((VId)`count`) = "count";
str agg2sql((VId)`sum`) = "sum";
str agg2sql((VId)`avg`) = "avg";
str agg2sql((VId)`min`) = "min";
str agg2sql((VId)`max`) = "max";
 
default str agg2sql(VId x) {
  throw "Cannot convert aggregation function <x> to SQL";
}

alias Ctx
  = tuple[
      void(SQLExpr) addWhere,
      void(As) addFrom,
      void(str, As, SQLExpr) addLeftOuterJoin,
      void(SQLExpr) addResult,
      void(str, SQLExpr) addAggAlias,
      SQLExpr(str) getAlias,
      bool(str) isAlias,
      str(str, Param) getParam,
      Schema schema,
      Env env,
      set[str] dyns,
      int() vars,
      Place place
   ];


tuple[SQLStat, Bindings] compile2sql((Request)`<Query q>`, Schema s, Place p, Log log = noLog, SQLAggWeaver weave = noAgg)
  = select2sql(q, s, p, log = log, weave = weave);

tuple[SQLStat, Bindings] select2sql((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs>`, Schema s, Place p
                           , Log log = noLog, SQLAggWeaver weave = noAgg) 
  = select2sql((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where true`, s, p, log = log, weave = weave);

/*

Steps to compile to SQL

- add the results to the SQL results after select except if #delayed or #done
- add the bindings to the SQL from clause with "as" except if #dynamic or #ignored
- add the required (junction) tables from relation navigation to the select clause
- add to the result the expressions used in #needed expressions
- translate refs to #dynamic entities to named placeholders, put the expression itself into params
- translate where clauses to sql where clause, possibly using junction tables, skip #done/#needed/#delayed


*/
tuple[SQLStat, Bindings] select2sql(q:(Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ ws>`
  , Schema s, Place p, Log log = noLog, SQLAggWeaver weave = noAgg) {

  // println(q);
  SQLStat q = select([], [], [where([])]);
  
  void addWhere(SQLExpr e) {
    // println("ADDING where clause: <pp(e)>");
    q.clauses[0].exprs += [e];
  }
  
  void addFrom(As as) {
    // println("ADDING table: <pp(as)>");
    q.tables += [as];
  }
  
  bool hasTableRight(As as, str tbl) {
    if (as has name) {
      return as.name == tbl;
    }
    return hasTableRight(as.left, tbl);
  }
  
  void addLeftOuterJoin(str this, As other, SQLExpr on) {
    // println("OUTER: this = <this>, other = <pp(other)>, on = <on>");
    for (int i <- [0..size(q.tables)]) {
      // me:as(_, this)
      // println("TABLEs[<i>] = <q.tables[i]>");
      // println("hasTableRight(<q.tables[i]>, <this>) = <hasTableRight(q.tables[i], this)>");
      if (As me := q.tables[i], hasTableRight(me, this)) {
        // we lose the original `other` table here...
        // if we update, so we append
        if (me is leftOuterJoin) {
          me.rights += [other];
          me.ons += [on];
          q.tables[i] = me;
        }
        else {
          q.tables[i] = leftOuterJoin(me, [other], [on]);
        }
        //q.tables += [leftOuterJoin(me, other, on)];
        return;
      } 
    }
    throw "Could not find source tbl for outer join: <this> with <other> on <on>";
  }
  
  void addResult(SQLExpr e) {
    // println("ADDING result: <pp(e)>");
    q.exprs += [e];
  }
  
  map[str, SQLExpr] aliases = ();
  
  void addAggAlias(str name, SQLExpr al) {
    aliases[name] = al;
  }
  
  bool isAlias(str name) {
    return name in aliases;
  }
  
  
  SQLExpr getAlias(str name) {
    return aliases[name];
  }
  
  int _vars = -1;
  int vars() {
    return _vars += 1;
  }

  Bindings params = ();
  void addParam(str x, Param field) {
    params[x] = field;
  }
  
  
  map[Param, str] placeholders = ();
  str getParam(str prefix, Param field) {
    if (field notin placeholders) {
      str name = "<prefix>_<vars()>";
      placeholders[field] = name;
      addParam(name, field);
    } 
    return placeholders[field];
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
     addLeftOuterJoin,
     addResult,
     addAggAlias,
     getAlias,
     isAlias,
     getParam,
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
           addResult(named(expr2sql(x, ctx), "<y>.<ent>.@id"));
           for (<ent, str a, str _> <- ctx.schema.attrs) {
             Id f = [Id]a;
             addResult(named(expr2sql((Expr)`<VId y>.<Id f>`, ctx), "<y>.<ent>.<f>"));
           }
         }
       }
      case x:(Expr)`<VId y>.@id`: {
         log("##### record results: var <y>.@id");
    
         if (str ent := env["<y>"], <p, ent> <- ctx.schema.placement) {
           addResult(named(expr2sql(x, ctx), "<y>.<ent>.@id"));
         }
      }
      case x:(Expr)`<VId y>.<Id f>`: {
         log("##### record results: <y>.<f>");
    
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

  
  // NB: this needs to happen before adding
  // results, because "."-expressions in
  // results require tables for joining.
  for ((Binding)`<EId e> <VId x>` <- bs) {
    // skipping #dynamic / #ignored
    addFrom(as(tableName("<e>"), "<x>"));
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
  
  if (q.clauses[0].exprs == []) {
    q.clauses = [];
  }
  
  //println("BEFORE aggregation: <q>");
  // println("PARAMS: <params>");
  return <weave(q, ctx), params>;
}



str varForTarget(Id f, int i) = "<f>$<i>";

str varForJunction(Id f, int i) = "junction_<f>$<i>";


SQLExpr expr2sql(e:(Expr)`<VId x>`, Ctx ctx, Log log = noLog) {
  str var = "<x>";
  if (ctx.isAlias(var)) {
    return ctx.getAlias(var);
  }
  return expr2sql((Expr)`<VId x>.@id`, ctx);
}


SQLExpr expr2sql(e:(Expr)`<VId x>.@id`, Ctx ctx, Log log = noLog) {
  if ("<x>" in ctx.dyns, str ent := ctx.env["<x>"], <Place p, ent> <- ctx.schema.placement) {
    str token = ctx.getParam("<x>", field(p.name, "<x>", ctx.env["<x>"], "@id"));
    return SQLExpr::placeholder(name=token);
  }
  str entity = ctx.env["<x>"];
  return column("<x>", typhonId(entity));
}
  
// only one level of navigation because of normalization
SQLExpr expr2sql(e:(Expr)`<VId x>.<Id f>`, Ctx ctx, Log log = noLog) {
  log("TRANSLATING: <e>");
  str entity = ctx.env["<x>"];
  str role = "<f>"; 

  if ("<x>" in ctx.dyns, str ent := ctx.env["<x>"], <Place p, ent> <- ctx.schema.placement) {
    str token = ctx.getParam("<x>_<f>", field(p.name, "<x>", ctx.env["<x>"], "<f>"));
    return SQLExpr::placeholder(name=token);
  }

  
  if (<entity, _, role, str toRole, _, str to, true> <- ctx.schema.rels, placeOf(to, ctx.schema) == ctx.place) {
    // println("########### local containment <entity> -<role>/<toRole>-\> <to>");
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
    // println("########### local (reverse) containment <parent> -<parentRole>/<role>-\> <entity>");
    str tbl1 = "<x>";
    return column(tbl1, fkName(parent, entity, role));
  }
  else if (<entity, _, role, str toRole, _, str to, _> <- ctx.schema.rels) {
  	// println("######### xref, or external containment: <entity> -<role>/<toRole>-\> <to> (`<e>`)  ");
  	tbl1 = "<x>";
    tbl2 = varForJunction(f, ctx.vars());

    //ctx.addFrom(as(junctionTableName(entity, role, to, toRole), tbl2));

    ctx.addLeftOuterJoin(tbl1,  	
  	  as(junctionTableName(entity, role, to, toRole), tbl2),
  	  equ(column(tbl2, junctionFkName(entity, role)), column(tbl1, typhonId(entity))));
  	
  	// return the column of the target
  	return column(tbl2, junctionFkName(to, toRole));
  }
  else if (<entity, role, str atype> <- ctx.schema.attrs) { 
    log("# an attribute <entity>.<role>");
    normalAccess = column("<x>", columnName(role, entity));
    if (atype in {"point", "polygon"}) {
        return fun("ST_AsWKB", [normalAccess]);
    }
    return normalAccess;
  }
  else {
    throw "Unsupported navigation in SQL <entity> <x>.<role>";
  }
}  
  

SQLExpr expr2sql((Expr)`<PlaceHolder ph>`, Ctx ctx, Log log = noLog) = SQLExpr::placeholder(name = "<ph.name>");

SQLExpr expr2sql((Expr)`<Int i>`, Ctx ctx, Log log = noLog) = lit(integer(toInt("<i>")));
//SQLExpr expr2sql((Expr)`-<Int i>`, Ctx ctx, Log log = noLog) = lit(integer(toInt("-<i>")));

SQLExpr expr2sql((Expr)`<Real r>`, Ctx ctx, Log log = noLog) = lit(decimal(toReal("<r>")));
//SQLExpr expr2sql((Expr)`-<Real r>`, Ctx ctx, Log log = noLog) = lit(decimal(toReal("-<r>")));

SQLExpr expr2sql((Expr)`<Str s>`, Ctx ctx, Log log = noLog) = lit(text(unescapeQLString(s)));

SQLExpr expr2sql((Expr)`<DateAndTime d>`, Ctx ctx, Log log = noLog) = lit(dateTime(convert(d)));

SQLExpr expr2sql((Expr)`<JustDate d>`, Ctx ctx, Log log = noLog) = lit(date(convert(d)));

SQLExpr expr2sql((Expr)`#point(<Real x> <Real y>)`, Ctx ctx, Log log = noLog) = lit(point(toReal("<x>"), toReal("<y>")));

SQLExpr expr2sql((Expr)`#polygon(<{Segment ","}* segments>)`, Ctx ctx, Log log = noLog) 
    = lit(polygon([ [<toReal("<x>"), toReal("<y>")> | (XY)`<Real x> <Real y>` <- s.points] | s <- segments]));


SQLExpr expr2sql((Expr)`false`, Ctx ctx, Log log = noLog) = lit(boolean(false));

SQLExpr expr2sql((Expr)`??<Id name>`, Ctx ctx, Log log = noLog) = SQLExpr::placeholder(name = "<name>");

SQLExpr expr2sql((Expr)`<UUID u>`, Ctx ctx, Log log = noLog) = lit(sUuid("<u.part>"));

SQLExpr expr2sql((Expr)`<BlobPointer bp>`, Ctx ctx, Log log = noLog) = lit(blobPointer("<bp.part>"));

SQLExpr expr2sql((Expr)`true`, Ctx ctx, Log log = noLog) = lit(boolean(true));

SQLExpr expr2sql((Expr)`false`, Ctx ctx, Log log = noLog) = lit(boolean(false));

SQLExpr expr2sql((Expr)`(<Expr e>)`, Ctx ctx, Log log = noLog) = expr2sql(e, ctx);

SQLExpr expr2sql((Expr)`null`, Ctx ctx, Log log = noLog) = lit(null());

SQLExpr expr2sql((Expr)`+<Expr e>`, Ctx ctx, Log log = noLog) = pos(expr2sql(e, ctx));

SQLExpr expr2sql((Expr)`-<Expr e>`, Ctx ctx, Log log = noLog) = neg(expr2sql(e, ctx));

SQLExpr expr2sql((Expr)`!<Expr e>`, Ctx ctx, Log log = noLog) = not(expr2sql(e, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> * <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = mul(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> / <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = div(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> + <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = add(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> - <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = sub(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> == <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = equ(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> != <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = neq(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> \>= <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = geq(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> \<= <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = leq(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> \> <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = gt(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> \< <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = lt(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> like <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = like(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> && <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = and(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr expr2sql((Expr)`<Expr lhs> || <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = or(expr2sql(lhs, ctx), expr2sql(rhs, ctx));

SQLExpr removeWKB(fun("ST_AsWKB", [a])) = a;
default SQLExpr removeWKB(SQLExpr other) = other;

SQLExpr expr2sql((Expr)`<Expr lhs> & <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = equ(fun("ST_Intersects", [removeWKB(expr2sql(lhs, ctx)), removeWKB(expr2sql(rhs, ctx))]), lit(integer(1)));

SQLExpr expr2sql((Expr)`<Expr lhs> in <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = equ(fun("ST_Within", [removeWKB(expr2sql(lhs, ctx)), removeWKB(expr2sql(rhs, ctx))]), lit(integer(1)));

SQLExpr expr2sql((Expr)`distance(<Expr from>, <Expr to>)`, Ctx ctx, Log log = noLog)
  = mul(fun("ST_Distance", [removeWKB(expr2sql(from, ctx)), removeWKB(expr2sql(to, ctx))]), lit(integer(1000)));

default SQLExpr expr2sql(Expr e, Ctx _) { throw "Unsupported expression in SQL: <e>"; }



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
  s = schema(
  { "Person", "Review", "Comment", "Reply" },
  {
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
  s = schema(
  { "Person", "Review", "Comment", "Reply" },
  {
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
