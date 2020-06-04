module lang::typhonql::Normalize


import lang::typhonml::TyphonML;
import lang::typhonml::Util;
import lang::typhonml::XMIReader;
import lang::typhonql::TDBC;



import IO;
import Set;
import String;
import List;


/*
 *
 * Normalization
 *
 */

Request addWhereIfAbsent((Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs>`)
  = (Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where true`;
  
default Request addWhereIfAbsent(Request r) = r; 


void smokeNormalize() {
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
  
  q = (Request)`from Person p, Review r select r.comment.replies.reply where r.user.age \> 10, r.user.name == "Pablo"`;
  println(expandNavigation(q, s));
}

Request elicitBindings(req:(Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ ws>`, Schema s) {

}


void smokeKeyValInf() {
  s = schema(
  {
    <"Review",\one(),"user","reviews",zero_many(),"User",false>,
    <"Product",zero_many(),"tags","tags^",zero_one(),"Tag",false>,
    <"Product",zero_many(),"reviews","product",\one(),"Review",true>,
    <"Product",\one(),"category","category^",zero_one(),"Category",false>,
    <"Item",\one(),"product","inventory",zero_many(),"Product",false>,
    <"Product",zero_many(),"inventory","product",\one(),"Item",true>,
    <"User",zero_many(),"reviews","user",\one(),"Review",false>,
    <"Review",\one(),"product","reviews",zero_many(),"Product",false>,
    <"User",zero_one(),"biography","user",\one(),"Biography",true>,
    <"Biography",\one(),"user","biography",zero_one(),"User",false>,
    <"User",\one(),"Stuff__","",\one(),"User__Stuff",true>,
    <"User",\one(),"MoreStuff__","",\one(),"User__MoreStuff",true>
  },
  {
    <"User","name","string(256)">,
    <"Review","location","point">,
    <"Product","productionDate","date">,
    <"User","address","string(256)">,
    <"Product","description","string(256)">,
    <"Product","name","string(256)">,
    <"Product","price","int">,
    <"Tag","name","string(64)">,
    <"User","billing","address">,
    <"User__Stuff","photoURL","string(256)">,
    <"Category","name","string(32)">,
    <"Biography","content","string(256)">,
    <"User__Stuff","avatarURL","string(256)">,
    <"User__MoreStuff","bla","string(256)">,
    <"Product","availabilityRegion","polygon">,
    <"Category","id","string(32)">,
    <"Review","content","text">,
    <"Item","shelf","int">,
    <"User","location","point">
  },
  customs={
    <"address","location","point">,
    <"address","zipcode","string(42)">,
    <"address","street","string(256)">,
    <"address","city","string(256)">
  },
  placement={
    <<cassandra(),"Stuff">,"User__Stuff">,
    <<cassandra(),"Stuff">,"User__MoreStuff">,
    <<sql(),"Inventory">,"User">,
    <<sql(),"Inventory">,"Product">,
    <<sql(),"Inventory">,"Item">,
    <<sql(),"Inventory">,"Tag">,
    <<mongodb(),"Reviews">,"Biography">,
    <<mongodb(),"Reviews">,"Review">,
    <<mongodb(),"Reviews">,"Category">
  },
  changeOperators=[]);
  
  Request r = (Request)`from User u select u.avatarURL, u.photoURL where u.photoURL == 34`;
  println("Original: <r>");
  println(inferKeyValLinks(r, s));
  
  println("");
  
  r = (Request)`from Review r select r.user.avatarURL, r.user.photoURL where r.user.photoURL == 34`;
  println("Original: <r>");
  println(inferKeyValLinks(r, s));
  
  println("");
  
  r = (Request)`from User u select u.avatarURL, u.bla where u.photoURL == 34`;
  println("Original: <r>");
  println(inferKeyValLinks(r, s));
  
  
}


list[str] isKeyValAttr(str ent, str f, Schema s) {
    // return the inferred entity role if f is a key val attribute
    // otherwise return empty.
    return [ role, kve | <ent, \one(), str role, _, \one(), str kve, true> <- s.rels
              , <kve, f, _> <- s.attrs
              , <<cassandra(), _>, kve> <- s.placement ];
    
} 

Request inferKeyValLinks(req:(Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ ws>`, Schema s) {
  // rewrite x.f -> x.A__B.f if f is an attribute that is mapped from keyVal
  Env env = queryEnv(bs);
  
  
  
  str inferTarget(str src, list[Id] ids) {
    if (ids == []) {
      return src;
    }
    str via = "<ids[0]>";
    if (<src, Cardinality _, via,  str _, Cardinality _, str trg, _> <- s.rels) {
      return inferTarget(trg, ids[1..]);
    }
    else {
      throw "Invalid role `<via>` for entity <src>";
    }
  }
  
  int varId = 0;
  map[str, VId] memo = ();
  list[Binding] newBindings = [ b | Binding b <- bs ];
  
  VId newBinding(str entity, str path, Expr whereRhs) {
    str key = "<entity>/<path>";
    if (key notin memo) {
      str x = "<uncapitalize(entity)>_kv_<varId>";
      varId += 1;
      VId var = [VId]x;
      memo[key] = var;
      EId ent = [EId]entity;
      newBindings += [(Binding)`<EId ent> <VId var>`]; 
      newWheres += [(Expr)`<VId var>.@id == <Expr whereRhs>`];
    }
    return memo[key];
  }
  
  
  // NB: empty, because they are rewritten, so added later
  list[Result] newResults = [];
  list[Expr] newWheres = [];
  
  req = visit (req) {
    case (Expr)`<VId x>.<Id f>`: {
      str src = inferTarget(env["<x>"], []);
      if ([str role, str kvEntity] := isKeyValAttr(src, "<f>", s)) {
        VId kvX = newBinding(kvEntity, "<x>", (Expr)`<VId x>.@id`);
        insert (Expr)`<VId kvX>.<Id f>`;
        
        /*
          add binding: kvEntity kvVar
          add where:  kvVar.@id == x.@id
          replace with: kvVar.f
        */
      }
    }
    // whoa bug: mathcing {Id "."}+ against {Id ","}+ pattern succeeds
    case (Expr)`<VId x>.<{Id "."}+ fs>.<Id f>`: {
      str src = inferTarget(env["<x>"], [ a | Id a <- fs ]);
      if ([str role, str kvEntity] := isKeyValAttr(src, "<f>", s)) {
        VId kvX = newBinding(kvEntity, "<x>.<fs>", (Expr)`<VId x>.<{Id "."}+ fs>`);
        insert (Expr)`<VId kvX>.<Id f>`;
        /*
          add binding: kvEntity kvVar
          add where:  kvVar.@id == x.<fs>.@id
          replace with: kvVar.f
        */
      }
    }
  }
  
  if ((Request)`from <{Binding ","}+ _> select <{Result ","}+ rs> where <{Expr ","}+ ws>` := req) {
    newResults = [ r | Result r <- rs ] + newResults;
    newWheres = [ w | Expr w <- ws ] + newWheres;
  }
  
  Query newQuery = buildQuery(newBindings, newResults, newWheres);
  return (Request)`<Query newQuery>`;
}

Request expandNavigation(req:(Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ ws>`, Schema s) {
  Env env = queryEnv(bs);
  
  int varId = 0;
  str newVar(str base) {
    str x = "<uncapitalize(base)>_<varId>";
    varId += 1;
    return x;
  }
  
  list[Binding] newBindings = [ b | Binding b <- bs ];
  
  // NB: empty, because they are rewritten, so added later
  list[Result] newResults = [];
  list[Expr] newWheres = [];
  
  rel[str entity, str role] done = {};
  
  bool change = true;
  
  bool doChange() {
    change = true;
    return true;
  }
  
  while (change) {
    change = false;
    
    // NB: a rel, so same prefix, will be once in the set, and get the same binding/newvar
    rel[str,str] varRoles = { <"<x>", "<f>"> | /(Expr)`<VId x>.<Id f>.<{Id "."}+ fs>` := req };
    
    if (varRoles == {}) {
      // no more paths > 2 to be expanded, so we're done
      break;
    }
    
    // iterate over var-role pairs, and find the target entity for each one of them
    for (<str var, str role> <- varRoles, str entity := env[var], <entity, _, role, _, _, str target, _> <- s.rels
          , <entity, role> notin done) {
      done += {<entity, role>};
      str y = newVar(target);
      env[y] = target;
      newBindings += [ [Binding]"<target> <y>" ];
      newWheres += [ [Expr]"<var>.<role> #join <y>" ];
      VId vid = [VId]y;
      
      req = visit (req) {
        case e:(Expr)`<VId x>.<Id f>.<{Id "."}+ fs>` => (Expr)`<VId vid>.<{Id "."}+ fs>`
          when
             "<x>" == var, "<f>" == role, doChange()
      }
    }
  }
  
  // peel out old, but rewritten where-clauses and results, and prepend before newWheres
  if ((Request)`from <{Binding ","}+ _> select <{Result ","}+ rs> where <{Expr ","}+ ws>` := req) {
    newResults = [ r | Result r <- rs ] + newResults;
    newWheres = [ w | Expr w <- ws ] + newWheres;
  }
  
  Query newQuery = buildQuery(newBindings, newResults, newWheres);
  return (Request)`<Query newQuery>`;
}


void smokeCustoms() {
  str xmi = readFile(|project://typhonql/src/lang/typhonql/test/resources/user-review-product/user-review-product.xmi|);
  Model m = xmiString2Model(xmi);
  Schema s = model2schema(m);
  
  req = (Request)`from User u select u.billing.street`;
  println(eliminateCustomDataTypes(req, s));

  req = (Request)`from User u select u.billing.zipcode.letters`;
  println(eliminateCustomDataTypes(req, s));

  req = (Request)`from Review r select r.user.billing.zipcode.letters`;
  println(eliminateCustomDataTypes(req, s));
}


Request eliminateCustomDataTypes(req:(Request)`<Query q>`, Schema s) {
  /*
    in results/where clauses 
      x.ctFld.fld  => x.ctFld$fld
      
    in keyvals
       fld: ct ( keyvals )
       =>
       fld$k: v for all k: v <- keyvals
  */
  
  env = queryEnv(q); 
  
  
  
  str reach(str ent, list[str] path) {
    if (path == []) {
      return ent;
    }
    
    str role = path[0];
    if (<ent, _, role, _, _, str target, _> <- s.rels) {
      return reach(target, path[1..]);  
    }
    
    return "";
  }
  
  return visit (req) {
    case (Expr)`<VId x>.<{Id "."}+ ids>.<Id f>`: {
      // this code assumes that
      // x.f (single field), never refers to custom data type attr
    
      list[str] trail = [ "<i>" | Id i <- ids ] + ["<f>"];
      
      // we're looking for a suffxi of ids + f
      // that has a dollared attribute in an entity
      // that is reachable from x with the prefix.
      
      if ([*str prefix, *str suffix] := trail, str ent := reach(env["<x>"], prefix),
           <ent, str name, _> <- s.attrs, name == intercalate("$", suffix)) {
         if (prefix == []) {
           insert [Expr]"<x>.<name>";
         }
         else {
           insert [Expr]"<x>.<intercalate(".", prefix)>.<name>";
         }    
      }
    }
   
  }
  
}


Request idifyEntities((Request)`<Query q>`, Schema s) {

}

Request canonicalizeRelations((Request)`<Query q>`, Schema s) {

}

Query buildQuery(list[Binding] bs, list[Result] rs, list[Expr] ws) {
  Binding b0 = bs[0];
  Result r0 = rs[0];
  Query q = (Query)`from <Binding b0> select <Result r0> where true`;
  
  int wherePos = 0;
  if (size(ws) > 0) {
    Expr w = ws[0];
    q = (Query)`from <Binding b0> select <Result r0> where <Expr w>`;
    wherePos = 1;
  }
  
  for (Binding b <- bs[1..]) {
    if ((Query)`from <{Binding ","}+ theBs> select <{Result ","}+ theRs> where <{Expr ","}+ theWs>` := q) {
      q = (Query)`from <{Binding ","}+ theBs>, <Binding b> select <{Result ","}+ theRs> where <{Expr ","}+ theWs>`;
    }
  }
  for (Result r <- rs[1..]) {
    if ((Query)`from <{Binding ","}+ theBs> select <{Result ","}+ theRs> where <{Expr ","}+ theWs>` := q) {
      q = (Query)`from <{Binding ","}+ theBs> select <{Result ","}+ theRs>, <Result r> where <{Expr ","}+ theWs>`;
    }
  }
  for (Expr w <- ws[wherePos..]) {
    if ((Query)`from <{Binding ","}+ theBs> select <{Result ","}+ theRs> where <{Expr ","}+ theWs>` := q) {
      q = (Query)`from <{Binding ","}+ theBs> select <{Result ","}+ theRs> where <{Expr ","}+ theWs>, <Expr w>`;
    }
  }
  return q;
}
