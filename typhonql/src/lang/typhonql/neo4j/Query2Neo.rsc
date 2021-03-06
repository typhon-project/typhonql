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
import lang::typhonql::util::Strings;
import lang::typhonql::util::Dates;

import IO;
import ValueIO;
import String;
import List;
import util::Maybe;


alias Ctx
  = tuple[
      void(NeoExpr) addWhere,
      void(str, str) addFrom,
      void(str, str) addSource,
      void(str, str) addTarget,
      //void(str, As, NeoExpr) addLeftOuterJoin,
      void(NeoExpr) addResult,
      void(str, Param) addParam,
      Schema schema,
      Env env,
      set[str] dyns,
      int(str) vars,
      Place place
   ];

str varConnect() = "__";


tuple[NeoStat, Bindings] compile2neo((Request)`<Query q>`, Schema s, Place p, Log log = noLog)
  = select2neo(q, s, p, log = log);

tuple[NeoStat, Bindings] select2neo((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs>`, Schema s, Place p, Log log = noLog) 
  = select2neo((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where true`, s, p, log = log);

tuple[NeoStat, Bindings] select2neo((Query)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ ws>`
  , Schema s, Place p, Log log = noLog) {

  NeoStat q = 
  	nMatchQuery(
  		[nMatch(
  			[], [nWhere([])])], 
  		[]);
  
  void addWhere(NeoExpr e) {
    // println("ADDING where clause: <pp(e)>");
    q.matches[0].clauses[0].exprs += [e];
  }
  
  void addFrom(str var, str label) {
    // println("ADDING table: <pp(as)>");
    q.matches[0].patterns += [nPattern(nNodePattern(var, [label], []), [])];
  }
  
   void addFrom2(str varName, str label) {
    // println("ADDING table: <pp(as)>");
    q.matches[0].patterns += 
    	[nPattern(
    		nNodePattern("<varName><varConnect()>from", [label], []),
	     	[nRelationshipPattern(nDoubleArrow(), varName,  label, [], nNodePattern("<varName><varConnect()>to", [], []))]
	     	)];
  }
  
  void addEdge(str varName, str label) {
  	q.matches[0].patterns += 
    	[nPattern(
    		nNodePattern("<varName><varConnect()>from", [], []),
	     	[nRelationshipPattern(nDoubleArrow(), varName,  label, [], nNodePattern("<varName><varConnect()>to", [], []))]
	     	)];
  }
  
  
  void addRelation(str var, str label) {
   q.matches[0].patterns[0].rels[0].var = var;
   q.matches[0].patterns[0].rels[0].label = label;
  }
  
  void addSource(str var, str label) {
    q.matches[0].patterns[0].nodePattern.var = var;
    q.matches[0].patterns[0].nodePattern.labels = [label];
  }
  
  void addTarget(str var, str label) {
    q.matches[0].patterns[0].rels[0].nodePattern.var = var;
    q.matches[0].patterns[0].rels[0].nodePattern.labels = [label];
  }
  
  void addResult(NeoExpr e) {
    // println("ADDING result: <pp(e)>");
    q.returnExprs += [e];
  }
  
  int _vars = -1;
  
  map[tuple[str, str], int] usedVars = (); 
  
  int vars(str name) {
  	return vars(name, "");
  }
  
  int vars(str name, str field) {
    if (<name, field> in usedVars)
  		return usedVars[<name, field>];
  	else {
    	_vars += 1;
    	usedVars += (<name, field> : _vars);
    	return _vars;
    }
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
     addSource,
     addTarget,
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
           addResult(nNamed(expr2neo(x, ctx), "<y>.<ent>.@id"));
         }
      }
      case x:(Expr)`<VId y>.<Id f>`: {
         log("##### record results: <y>.<f>");
    
         if (str ent := env["<y>"], <p, ent> <- ctx.schema.placement) {
           addResult(nNamed(expr2neo(x, ctx), "<y>.<ent>.<f>"));
           // todo: should be in Normalize
           idExpr = nNamed(expr2neo((Expr)`<VId y>.@id`, ctx), "<y>.<ent>.@id");
           if (idExpr notin q.returnExprs) {
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
    addEdge("<x>", "<e>");
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
  
  if (q.matches[0].clauses[0].exprs == []) {
    q.matches[0].clauses = [];
  }
  
  // println("PARAMS: <params>");
  return <q, params>;
}

NeoExpr expr2neo(e:(Expr)`<VId x>`, Ctx ctx, Log log = noLog)
  = expr2neo((Expr)`<VId x>.@id`, ctx);


NeoExpr expr2neo(e:(Expr)`<VId x>.@id`, Ctx ctx, Log log = noLog) {
  if ("<x>" in ctx.dyns, str ent := ctx.env["<x>"], <Place p, ent> <- ctx.schema.placement) {
    str token = "<x>_<ctx.vars("<x>", "")>";
    ctx.addParam(token, field(p.name, "<x>", ctx.env["<x>"], "@id"));
    return NeoExpr::nPlaceholder(name=token);
  }
  str entity = ctx.env["<x>"];
  return nProperty("<x>", neoTyphonId(entity));
}
  
// only one level of navigation because of normalization
NeoExpr expr2neo(e:(Expr)`<VId x>.<Id f>`, Ctx ctx, Log log = noLog) {
  log("TRANSLATING: <e>");
  str entity = ctx.env["<x>"];
  str role = "<f>"; 

  if ("<x>" in ctx.dyns, str ent := ctx.env["<x>"], <Place p, ent> <- ctx.schema.placement) {
    str token = "<x>_<f>_<ctx.vars("<x>", "<f>")>";
    ctx.addParam(token, field(p.name, "<x>", ctx.env["<x>"], "<f>"));
    return nPlaceholder(name=token);
  }

  // TODO translate to neo
  if (<entity, _, role, str toRole, _, str to, true> <- ctx.schema.rels, placeOf(to, ctx.schema) == ctx.place) {
    ;
    /*log("########### local containment <entity> -<role>/<toRole>-\> <to>");
    str tbl1 = "<x>";
    str tbl2 = varForTarget(f, ctx.vars()); // introduce a new table alias
    ctx.addLeftOuterJoin(tbl1,
       as(tableName(to), tbl2),
       equ(column(tbl2, fkName(entity, to, toRole)), column(tbl1, typhonId(entity))));
       
    // the value is of this expression is the id column of the child table
    // provided that its parent is the table representing x 
    return column(tbl2, typhonId(to));*/
  }
  else if (<str parent, _, str parentRole, role, _, entity, true> <- ctx.schema.rels, placeOf(parent, ctx.schema) == ctx.place) {
    ;
    //log("########### local (reverse) containment <parent> -<parentRole>/<role>-\> <entity>");
    //str tbl1 = "<x>";
    //return column(tbl1, fkName(parent, entity, role));
  }
  else if (<entity, _, role, str toRole, _, str to, _> <- ctx.schema.rels) {
  	log("######### xref, or external containment: <entity> -<role>/<toRole>-\> <to> (`<e>`)  ");
  	//node1 = "<x>";
    //node2 = "<f>";
	
	//int n = ctx.vars("<f>", "");
	//str var = "<f>_<n>"
	/*if (isFrom(entity, role, ctx.place, ctx.schema)) {
		ctx.addSource(var, to);
	} else if (isTo(entity, role, ctx.place, ctx.schema)) {
		ctx.addTarget(var, to);
	}
	/*if (isFrom(entity, role, ctx.place, ctx.schema)) {
		ctx.addSource(var, to);
	} else if (isTo(entity, role, ctx.place, ctx.schema)) {
		ctx.addTarget(var, to);
	} else {
		ctx.addFrom(var, to);
	}*/
	//ctx.addWhere(equ(property(node1, nodeName(entity,node2)), property(var, nodeName(to, "@id"))));
	//ctx.addWhere(equ(property(node1, node2), property("X", node2)));

    //ctx.addLeftOuterJoin(tbl1,  	
  	//  as(junctionTableName(entity, role, to, toRole), tbl2),
  	//  equ(column(tbl2, junctionFkName(entity, role)), column(tbl1, typhonId(entity))));
  	
  	// return the column of the target
  	if (isFrom(entity, role, ctx.place, ctx.schema)) {
		return nProperty("<x><varConnect()>from", nodeName("<to>", "@id"));
	} else if (isTo(entity, role, ctx.place, ctx.schema)) {
		return nProperty("<x><varConnect()>to", nodeName("<to>", "@id"));
	}
  	//
  }
  else if (<entity, role, str atype> <- ctx.schema.attrs) { 
    log("# an attribute <entity>.<role>");
    normalAccess = nProperty("<x>", nodeName(entity, role));
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

bool isFrom(str entity, str relName, Place p:<neo4j(), dbName>, Schema s) {
	return  <dbName, graphSpec({ _*, <entity, relName, _> , _*})> <- s.pragmas; 
}

bool isTo(str entity, str relName, Place p:<neo4j(), dbName>, Schema s) {
	return  <dbName, graphSpec({ _*, <entity, _, relName> , _*})> <- s.pragmas;
}

NeoExpr expr2neo((Expr)`<PlaceHolder ph>`, Ctx ctx, Log log = noLog) = NeoExpr::nPlaceholder(name = "<ph.name>");

NeoExpr expr2neo((Expr)`<Int i>`, Ctx ctx, Log log = noLog) = nLit(nInteger(toInt("<i>")));
//NeoExpr expr2neo((Expr)`-<Int i>`, Ctx ctx, Log log = noLog) = nLit(nInteger(toInt("-<i>")));

NeoExpr expr2neo((Expr)`<Real r>`, Ctx ctx, Log log = noLog) = nLit(nDecimal(toReal("<r>")));
//NeoExpr expr2neo((Expr)`-<Real r>`, Ctx ctx, Log log = noLog) = nLit(nDecimal(toReal("-<r>")));

NeoExpr expr2neo((Expr)`<Str s>`, Ctx ctx, Log log = noLog) = nLit(nText(unescapeQLString(s)));

NeoExpr expr2neo((Expr)`<DateAndTime d>`, Ctx ctx, Log log = noLog) = nLit(nDateTime(convert(d)));

NeoExpr expr2neo((Expr)`<JustDate d>`, Ctx ctx, Log log = noLog) = nLit(nDate(convert(d)));

NeoExpr expr2neo((Expr)`#point(<Real x> <Real y>)`, Ctx ctx, Log log = noLog) = nLit(nPoint(toReal("<x>"), toReal("<y>")));

NeoExpr expr2neo((Expr)`#polygon(<{Segment ","}* segments>)`, Ctx ctx, Log log = noLog) 
    = nLit(nPolygon([ [<toReal("<x>"), toReal("<y>")> | (XY)`<Real x> <Real y>` <- s.points] | s <- segments]));


NeoExpr expr2neo((Expr)`false`, Ctx ctx, Log log = noLog) = nLit(nBoolean(false));

NeoExpr expr2neo((Expr)`<UUID u>`, Ctx ctx, Log log = noLog) = nLit(nText("<u>"[1..]));

NeoExpr expr2neo((Expr)`true`, Ctx ctx, Log log = noLog) = nLit(nBoolean(true));

NeoExpr expr2neo((Expr)`false`, Ctx ctx, Log log = noLog) = nLit(nBoolean(false));

NeoExpr expr2neo((Expr)`(<Expr e>)`, Ctx ctx, Log log = noLog) = expr2neo(e, ctx);

NeoExpr expr2neo((Expr)`null`, Ctx ctx, Log log = noLog) = nLit(nNull());

NeoExpr expr2neo((Expr)`+<Expr e>`, Ctx ctx, Log log = noLog) = nPos(expr2neo(e, ctx));

NeoExpr expr2neo((Expr)`-<Expr e>`, Ctx ctx, Log log = noLog) = nNeg(expr2neo(e, ctx));

NeoExpr expr2neo((Expr)`!<Expr e>`, Ctx ctx, Log log = noLog) = nNot(expr2neo(e, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> * <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = nMul(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> / <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = nDiv(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> + <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = nAdd(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> - <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = nSub(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> == <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = nEqu(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> != <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = nNeq(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> \>= <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = nGeq(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> \<= <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = nLeq(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> \> <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = nGt(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> \< <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = nLt(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> like <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = nLike(expr2neo(lhs, ctx), expr2neo(rhs, ctx));
  
NeoExpr expr2neo((Expr)`<VId lhs> <Reaching r> <VId rhs>`, Ctx ctx, Log log = noLog) {
  ctx.addFrom("<lhs>", ctx.env["<lhs>"]);
  ctx.addFrom("<rhs>", ctx.env["<rhs>"]);
  ctx.addWhere(nEqu(nVariable("<r.edge><varConnect()>from"),nVariable("<lhs>")));
  ctx.addWhere(nEqu(nVariable("<r.edge><varConnect()>to"),nVariable("<rhs>")));
  
  return reachingExpr2neo(r, lhs, rhs, ctx, log = log);
}

NeoExpr expr2neo((Expr)`<Expr lhs> && <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = nAnd(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr expr2neo((Expr)`<Expr lhs> || <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = nOr(expr2neo(lhs, ctx), expr2neo(rhs, ctx));

NeoExpr removeWKB(fun("ST_AsWKB", [a])) = a;
default NeoExpr removeWKB(NeoExpr other) = other;

NeoExpr expr2neo((Expr)`<Expr lhs> & <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = nEqu(nFun("ST_Intersects", [removeWKB(expr2neo(lhs, ctx)), removeWKB(expr2neo(rhs, ctx))]), nLit(nInteger(1)));

NeoExpr expr2neo((Expr)`<Expr lhs> in <Expr rhs>`, Ctx ctx, Log log = noLog) 
  = nEqu(nFun("ST_Within", [removeWKB(expr2neo(lhs, ctx)), removeWKB(expr2neo(rhs, ctx))]), nLit(nInteger(1)));

NeoExpr expr2neo((Expr)`distance(<Expr from>, <Expr to>)`, Ctx ctx, Log log = noLog)
  = fun("ST_Distance", [removeWKB(expr2neo(from, ctx)), removeWKB(expr2neo(from, ctx))]);

default NeoExpr expr2neo(Expr e, Ctx _) { throw "Unsupported expression: <e>"; }

/*
NeoExpr expr2neo(e:(Expr)`<VId x>.<Id f>`, Ctx ctx, Log log = noLog) {
  log("TRANSLATING: <e>");
  str entity = ctx.env["<x>"];
  str role = "<f>"; 

  if ("<x>" in ctx.dyns, str ent := ctx.env["<x>"], <Place p, ent> <- ctx.schema.placement) {
    str token = "<x>_<f>_<ctx.vars("<x>", "f")>";
    ctx.addParam(token, field(p.name, "<x>", ctx.env["<x>"], "<f>"));
    return nPlaceholder(name=token);
  }

  // TODO translate to neo
  if (<entity, _, role, str toRole, _, str to, true> <- ctx.schema.rels, placeOf(to, ctx.schema) == ctx.place) {
    ;
    //log("########### local containment <entity> -<role>/<toRole>-\> <to>");
    //str tbl1 = "<x>";
    //str tbl2 = varForTarget(f, ctx.vars()); // introduce a new table alias
    //ctx.addLeftOuterJoin(tbl1,
    //   as(tableName(to), tbl2),
    //   equ(column(tbl2, fkName(entity, to, toRole)), column(tbl1, typhonId(entity))));
       
    // the value is of this expression is the id column of the child table
    // provided that its parent is the table representing x 
    //return column(tbl2, typhonId(to));
  }
  else if (<str parent, _, str parentRole, role, _, entity, true> <- ctx.schema.rels, placeOf(parent, ctx.schema) == ctx.place) {
    log("########### local (reverse) containment <parent> -<parentRole>/<role>-\> <entity>");
    str tbl1 = "<x>";
    return column(tbl1, fkName(parent, entity, role));
  }
  else if (<entity, _, role, str toRole, _, str to, _> <- ctx.schema.rels) {
  	log("######### xref, or external containment: <entity> -<role>/<toRole>-\> <to> (`<e>`)  ");
  	node1 = "<x>";
    node2 = "<f>";
	
	int n = ctx.vars("<f>", "");
	str var = "<f>_<n>";
	//if (isFrom(entity, role, ctx.place, ctx.schema)) {
	//	ctx.addSource(var, to);
	//} else if (isTo(entity, role, ctx.place, ctx.schema)) {
	//	ctx.addTarget(var, to);
	//} else {
	//	ctx.addFrom(var, to);
	//}
	//ctx.addWhere(equ(property(node1, nodeName(entity,node2)), property(var, nodeName(to, "@id"))));
	//ctx.addWhere(equ(property(node1, node2), property("X", node2)));

    //ctx.addLeftOuterJoin(tbl1,  	
  	//  as(junctionTableName(entity, role, to, toRole), tbl2),
  	//  equ(column(tbl2, junctionFkName(entity, role)), column(tbl1, typhonId(entity))));
  	
  	// return the column of the target
  	return nProperty(var, nodeName(to, "@id"));
  }
  else if (<entity, role, str atype> <- ctx.schema.attrs) { 
    log("# an attribute <entity>.<role>");
    normalAccess = nProperty("<x>", nodeName(entity, role));
    if (atype in {"point", "polygon"}) {
        return fun("ST_AsWKB", [normalAccess]);
    }
    return normalAccess;
  }
  else {
    throw "Unsupported navigation <entity> <x>.<role>";
  }
  
  */

NeoExpr reachingExpr2neo((Reaching) `-[ <VId edge> ]-\>`, VId lhs, VId rhs, Ctx ctx, Log log = noLog) 
  = nReaching(ctx.env["<edge>"], Maybe::nothing(), Maybe::nothing(), "<lhs>", "<rhs>");

NeoExpr reachingExpr2neo((Reaching) `-[ <Expr edge>, <Expr lower> .. ]-\>`, VId lhs, VId rhs, Ctx ctx, Log log = noLog) 
  = nReaching(ctx.env["<edge>"], lower, Maybe::nothing(), expr2neo(lhs, ctx, log=log), expr2neo(rhs, ctx, log=log));

NeoExpr reachingExpr2neo((Reaching) `-[ <Expr edge>, .. <Expr upper>]-\>`, VId lhs, VId rhs, Ctx ctx, Log log = noLog) 
  = nReaching(ctx.env["<edge>"], Maybe::nothing(), upper, expr2neo(lhs, ctx, log=log), expr2neo(rhs, ctx, log=log));

NeoExpr reachingExpr2neo((Reaching) `-[ <Expr edge>, <Expr lower> .. <Expr upper>]-\>`, VId lhs, VId rhs, Ctx ctx, Log log = noLog) 
  = nReaching(ctx.env["<edge>"], lower, upper, expr2neo(lhs, ctx, log=log), expr2neo(rhs, ctx, log=log));

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

Schema testSchema() = schema(
  { "Concordance", "Product", "Wish", "User", "Product" },
  {
    <"Concordance", \one(), "from", "from^", \one(), "Product", false>,
    <"Concordance", \one(), "to", "to^", \one(), "Product", false>,
    <"Product", \one(), "from^", "from", \one(), "Concordance", true>,
    <"Product", \one(), "to^", "to", \one(), "Concordance", true>,
    <"Wish", \one(), "user", "user^", \one(), "User", false>,
    <"Wish", \one(), "product", "product^", \one(), "Product", false>,
    <"User", \one(), "user^", "user", \one(), "Wish", true>,
    <"Product", \one(), "product^", "product", \one(), "Concordance", true>
  }, {
    <"Concordance", "weight", "int">,
    <"Product", "name", "string[256]">,
    <"User", "name", "string[256]">,
    <"Wish", "intensity", "int">
  },
  placement = {
    <<sql(), "Inventory">, "Product">,
    <<sql(), "Inventory">, "User">,
    <<neo4j(), "Concordance">, "Concordance">,
    <<neo4j(), "Concordance">, "Wish">
  },
  pragmas = {
  	<"Concordance", graphSpec({<"Concordance", "from", "to">, <"Wish", "user", "product">})>
  }
  );
  

void smoke2neoSelectWithAllOnSameNeoDB() {
  s = testSchema();	  
  println("\n\n#####");
  println("## ordered weights");
  Request q = (Request)`from Product p1, Product p2, Concordance c select c.weight where p1.name == "TV", p2.name == "Radio", c.from == p1, c.to == p2, c.weight \>10`;  
  println("Ordering <q>");
  order = orderPlaces(q, s);
  println("ORDER = <order>");
  for (Place p:<neo4j(), _> <- order) {
    println("\n\t#### Translation of <restrict(q, p, order, s)>");
   	<stat, params> = compile2neo(restrict(q, p, order, s), s, p); 
    println(stat);
    
    println(neopp(stat));
  }
  
}

void smoke2neoSelectWithAllOnSameNeoDB2() {
  s = testSchema();	  
  println("\n\n#####");
  println("## ordered weights");
  Request q = (Request)`from User u1, Product p1, Wish w select w.amount where u1.name == "Pablo", p1.name == "TV", w.product == p1, w.user == u1, w.amount \>10`;  
  println("Ordering <q>");
  order = orderPlaces(q, s);
  println("ORDER = <order>");
  for (Place p:<neo4j(), _> <- order) {
    println("\n\t#### Translation of <restrict(q, p, order, s)>");
   	<stat, params> = compile2neo(restrict(q, p, order, s), s, p); 
    println(stat);
    
    println(neopp(stat));
  }
  
}

void smoke2neoSelectWithAllOnSameNeoDB3() {
  s = testSchema();	  
  println("\n\n#####");
  println("## ordered weights");
  Request q = (Request)`from User u1, Product p1, Wish w select w.intensity where u1.name == "Pablo", p1.name == "TV", p1.wish == w, u1.wish == w, w.intensity \>10`;  
  println("Ordering <q>");
  order = orderPlaces(q, s);
  println("ORDER = <order>");
  for (Place p:<neo4j(), _> <- order) {
    println("\n\t#### Translation of <restrict(q, p, order, s)>");
   	<stat, params> = compile2neo(restrict(q, p, order, s), s, p); 
    println(stat);
    
    println(neopp(stat));
  }
  
}


void smoke2neoSelectWithAllOnSameNeoDB4() {
  s = testSchema();	  
  println("\n\n#####");
  println("## ordered weights");
  Request q = (Request)`from Wish w select w.intensity where w.@id ==#wish2`;  
  println("Ordering <q>");
  order = orderPlaces(q, s);
  println("ORDER = <order>");
  for (Place p:<neo4j(), _> <- order) {
    println("\n\t#### Translation of <restrict(q, p, order, s)>");
   	<stat, params> = compile2neo(restrict(q, p, order, s), s, p); 
    println(stat);
    
    println(neopp(stat));
  }
  
}
