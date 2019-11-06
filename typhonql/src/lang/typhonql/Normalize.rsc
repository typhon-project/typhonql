module lang::typhonql::Normalize


import lang::typhonml::TyphonML;
import lang::typhonml::Util;
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
  
  while (true) {
  
    // NB: a rel, so same prefix, will be once in the set, and get the same binding/newvar
    rel[str,str] varRoles = { <"<x>", "<f>"> | /(Expr)`<VId x>.<Id f>.<{Id "."}+ fs>` := req };
    
    if (varRoles == {}) {
      // no more paths > 2 to be expanded, so we're done
      break;
    }
    
    // iterate over var-role pairs, and find the target entity for each one of them
    for (<str var, str role> <- varRoles, str entity := env[var], <entity, _, role, _, _, str target, _> <- s.rels) {
      str y = newVar(target);
      env[y] = target;
      newBindings += [ [Binding]"<target> <y>" ];
      newWheres += [ [Expr]"<var>.<role> == <y>" ];
      VId vid = [VId]y;
      
      req = visit (req) {
        case e:(Expr)`<VId x>.<Id f>.<{Id "."}+ fs>` => (Expr)`<VId vid>.<{Id "."}+ fs>`
          when
             "<x>" == var, "<f>" == role
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
