module lang::typhonql::mongodb::Query2Mongo

import lang::typhonql::TDBC;
import lang::typhonql::Order;

import lang::typhonql::Session;
import lang::typhonml::TyphonML;
import lang::typhonml::Util;
import lang::typhonql::mongodb::DBCollection;

import List;
import IO;

////////
/////// TODO: normalization (e.g. expandNavigation) is SQL specific
/// for Mongo we need the paths.
/// so what if we always do SQL first, and then mongo, and
/// 
//////


/*

What if we totally restrict TyphonQL select for Mongo so that it matches Find?

from E x select x.a.b.c, x.f.b.c where 



*/

tuple[map[str, CollMethod], Bindings] compile2mongo(r:(Request)`<Query q>`, Schema s, Place p)
  = select2mongo(r, s, p);


alias Ctx = tuple[
    void(str,Field) addParam,
    Schema schema,
    Env env,
    set[str] dyns,
    int() vars,
    Place place];
    

tuple[map[str, CollMethod], Bindings] select2mongo((Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs>`, Schema s, Place p) 
  = select2mongo((Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where true`, s, p); 
    
tuple[map[str, CollMethod], Bindings] select2mongo((Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ ws>`, Schema s, Place p) {
  
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
  
  // mapping entity name to <collectionName, subPath> tuples
  map[str, tuple[str root, list[str] path]] paths
    =  ( "<e>" : localPathToEntity("<e>", s, p) | (Binding)`<EId e> <VId x>` <- bs );
    
  // mapping collection name to methods (i.e. `find`)
  map[str, CollMethod] result = ( paths["<e>"].root : find(object([]), object([])) | (Binding)`<EId e> <VId x>` <- bs );
  
  void addConstraint(str ent, <str path, DBObject val>) {
    // todo: if the path is already in props, create $and obj 
    prePath = paths[ent].path;
    if (prePath != []) {
      result[paths[ent].root].query.props += [<"<intercalate(".", paths[ent].path)>.<path>", val>];
    }
    else {
      result[paths[ent].root].query.props += [<path, val>];
    }
  }
  
  
  bool isLocal(VId x) = (str ent := env["<x>"] && <p, ent> <- s.placement);
    
  void addProjection(VId x, str fields) {
    if (!isLocal(x)) {
      return;
    }
    str ent = env["<x>"];
    prePath = paths[ent].path;
    if (prePath != []) {
      result[paths[ent].root].projection.props += [<"<intercalate(".", paths[ent].path)>.<fields>", \value(1)>];
    }
    else {
      result[paths[ent].root].projection.props += [<fields, \value(1)>];
    }
  } 

  // NB: VId x is local, because otherwise it would be dynamic or ignored
  // strong assumption here is that dot-notation is local and only containment
  for ((Result)`<VId x>.<{Id "."}+ fs>` <- rs) {
    addProjection(x, "<fs>");
  }
  
  int _vars = -1;
  int vars() {
    return _vars += 1;
  }
  
  Bindings params = (); 
  void addParam(str x, Field field) {
    params[x] = field;
  }
  
  
  Ctx ctx = <
    addParam,
    s,
    env,
    dyns,
    vars,
    p>;
  
    
  void recordProjections(Expr e) {
     visit (e) {
      case x:(Expr)`<VId y>`:
         addProjection(y, "_id");
      case x:(Expr)`<VId y>.@id`:
         addProjection(y, "_id");
      case x:(Expr)`<VId y>.<{Id "."}+ fs>`:
         addProjection(y, "<fs>");
    }
  }
  
  
  for (Expr e <- ws) {
    switch (e) {
      case (Expr)`#done(<Expr _>)`: ;
      case (Expr)`#delayed(<Expr _>)`: ;
      case (Expr)`#needed(<Expr x>)`: 
        recordProjections(x);

      default: {
        if ((Expr)`true` !:= e) {
          <ent, prop> = expr2pattern(e, ctx);
          addConstraint(ent, prop);
        }   
      }
    }
      
  }
  
  return <result, params>;
}

void smokeQuery2Mongo() {
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
  });
  
  str pp(find(DBObject query, DBObject projection))
    = "find(<pp(query)>, <pp(projection)>)";  	
  
  
  println("\n\n#####");
  Request q = (Request)`from Person p, Review r select r.text where p.name == "Pablo", p.reviews == r`;
  println("QUERY = <q>");  
  order = orderPlaces(q, s);
  for (Place p <- order, p.db == mongodb()) {
    println("\n\t#### Translation of <restrict(q, p, order, s)>");
    result = select2mongo(restrict(q, p, order, s), s, p); 
    iprintln(result);
    for (str coll <- result[0]) {
      println("db.<coll>.<pp(result[0][coll])>");
    }
  }
  
  
  println("\n\n#####");
  q = (Request)`from Comment c select c.contents where c.contents == "Pablo"`;  
  println("QUERY = <q>");  
  order = orderPlaces(q, s);
  for (Place p <- order, p.db == mongodb()) {
    println("\n\t#### Translation of <restrict(q, p, order, s)>");
    result = select2mongo(restrict(q, p, order, s), s, p); 
    iprintln(result);
    for (str coll <- result[0]) {
      println("db.<coll>.<pp(result[0][coll])>");
    }
  }
   
}

    

tuple[str, Prop] expr2pattern((Expr)`<Expr lhs> == <Expr rhs>`, Ctx ctx)
  = <ent, <path, expr2obj(other, ctx)>> 
  when
    <str ent, str path, Expr other> := split(lhs, rhs, ctx);
    
tuple[str, Prop] expr2pattern((Expr)`<Expr lhs> != <Expr rhs>`, Ctx ctx)
  = makeComparison("$ne", lhs, rhs, ctx);

tuple[str, Prop] expr2pattern((Expr)`<Expr lhs> \> <Expr rhs>`, Ctx ctx)
  = makeComparison("$gt", lhs, rhs, ctx);

tuple[str, Prop] expr2pattern((Expr)`<Expr lhs> \< <Expr rhs>`, Ctx ctx)
  = makeComparison("$lt", lhs, rhs, ctx);

tuple[str, Prop] expr2pattern((Expr)`<Expr lhs> \>= <Expr rhs>`, Ctx ctx)
  = makeComparison("$gte", lhs, rhs, ctx);

tuple[str, Prop] expr2pattern((Expr)`<Expr lhs> \<= <Expr rhs>`, Ctx ctx)
  = makeComparison("$lte", lhs, rhs, ctx);
  
// TODO: &&, ||, in, like


default tuple[str, Prop] expr2pattern(Expr e, Ctx ctx) { 
  throw "Unsupported expression: <e>"; 
}


  
tuple[str, Prop] makeComparison(str op, Expr lhs, Expr rhs, Ctx ctx) 
  = <ent, <path, object([<op, expr2obj(other, ctx)>])>> 
  when
    <str ent, str path, Expr other> := split(lhs, rhs, ctx);
    

// NB: restriction is that the same collection cannot be queried with different vars
// also paths in vars now must end at  primitives.
 
tuple[str ent, str path, Expr other] split(Expr lhs, Expr rhs, Ctx ctx) {
  if ((Expr)`<VId x>.<{Id "."}+ fs>` := lhs, "<x>" notin ctx.dyns) {
    return <ctx.env["<x>"], "<fs>", rhs>; 
  }
  if ((Expr)`<VId x>.@id` := lhs, "<x>" notin ctx.dyns) {
    return <ctx.env["<x>"], "_id", rhs>; 
  }

  if ((Expr)`<VId x>` := lhs, "<x>" notin ctx.dyns) {
    return <ctx.env["<x>"], "_id", rhs>;
  } 

  if ((Expr)`<VId x>.<{Id "."}+ fs>` := rhs, "<x>" notin ctx.dyns) {
    return <ctx.env["<x>"], "<fs>", lhs>;
  }
  if ((Expr)`<VId x>.@id` := rhs, "<x>" notin ctx.dyns) {
    return <ctx.env["<x>"], "_id", lhs>; 
  }

  if ((Expr)`<VId x>` := rhs, "<x>" notin ctx.dyns) {
    return <ctx.env["<x>"], "_id", lhs>; 
  }
  
  throw "One of binary expr must contain field navigation, but got: `<lhs>` and `<rhs>`";
}    

DBObject expr2obj(e:(Expr)`<VId x>.<{Id "."}+ fs>`, Ctx ctx) {
  if ("<x>" in ctx.dyns, str ent := ctx.env["<x>"], <Place p, ent> <- ctx.schema.placement) {
    str token = "<x>_<fs>_<ctx.vars()>";
    ctx.addParam(token, <p.name, "<x>", ctx.env["<x>"], "<fs>">);
    return placeholder(name=token);
  }
  throw "Only dynamic parameters can be used as expressions in query docs, not <e>";
}

DBObject expr2obj(e:(Expr)`<VId x>`, Ctx ctx) 
  = expr2obj((Expr)`<VId x>.@id`, ctx);
  
DBObject expr2obj(e:(Expr)`<VId x>.@id`, Ctx ctx) {
  if ("<x>" in ctx.dyns, str ent := ctx.env["<x>"], <Place p, ent> <- ctx.schema.placement) {
    str token = "<x>_@id_<ctx.vars()>";
    ctx.addParam(token, <p.name, "<x>", ctx.env["<x>"], "@id">);
    return placeholder(name=token);
  }
  throw "Only dynamic parameters can be used as expressions in query docs, not <e>";
}

DBObject expr2obj(e:(Expr)`<VId x>.<{Id "."}+ fs>`, Ctx ctx) {
  if ("<x>" in ctx.dyns, str ent := ctx.env["<x>"], <Place p, ent> <- ctx.schema.placement) {
    str token = "<x>_<fs>_<ctx.vars()>";
    ctx.addParam(token, <p.name, "<x>", ctx.env["<x>"], "<fs>">);
    return placeholder(name=token);
  }
  throw "Only dynamic parameters can be used as expressions in query docs, not <e>";
}



DBObject expr2obj((Expr)`?`, Ctx _) = placeholder();

DBObject expr2obj((Expr)`<UUID id>`, Ctx _) = \value("<id>"[1..]);

DBObject expr2obj((Expr)`<DateTime d>`, Ctx _) 
  = object([<"$date", \value(readTextValueString(#datetime, "<d>"))>]);

DBObject expr2obj((Expr)`<Int i>`, Ctx _) = \value(toInt("<i>"));

DBObject expr2obj((Expr)`<Real r>`, Ctx _) = \value(toReal("<r>"));

// todo: unescaping
DBObject expr2obj((Expr)`<Str s>`, Ctx _) = \value("<s>"[1..-1]);

DBObject expr2obj((Expr)`<Bool b>`, Ctx _) = \value("<b>" == "true");

default DBObject expr2obj(Expr e, Ctx _) { throw "Unsupported MongoDB restriction expression: <e>"; }