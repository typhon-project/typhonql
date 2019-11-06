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
    <"Comment", zero_many(), "replies", "owner", \zero_many(), "Reply", true>
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

/*
Since we key on entity type in added, this does not work with recursive unfoldings (e.g. Comments as replies to Comments).
*/
Request expandNavigation(req:(Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ ws>`, Schema s) {
  Env env = queryEnv(bs);
  
  int varId = 0;
  str newVar(str base) {
    str x = "<uncapitalize(base)>_<varId>";
    varId += 1;
    return x;
  }
  
  list[Binding] newBindings = [ b | Binding b <- bs ];
  
  // NB: empty, because they are rewritten
  list[Result] newResults = [];
  list[Expr] newWheres = [];

  map[str, str] added = ();
  set[str] todo = env<entity>;  


  Expr doIt(str x, str role, str target, {Id "."}+ fs) {
    if (target notin added) {
      str y = newVar(target);
      added[target] = y; 
      env[y] = target;
      todo += {target};
      newBindings += [ [Binding]"<target> <y>" ];
      newWheres += [ [Expr]"<x>.<role> == <y>" ];
    }
    VId y = [VId]added[target];
    return (Expr)`<VId y>.<{Id "."}+ fs>`;
  }

  while (todo != {}) {
    <entity, todo> = takeOneFrom(todo);
    
    for (<entity, _, str role, _, _, str target, _> <- s.rels) {
      req = visit (req) {
        case e:(Expr)`<VId x>.<Id f>.<{Id "."}+ fs>` => doIt("<x>", role, target, fs)
          when
             env["<x>"] == entity, "<f>" == role
      }
    }
  }
  
  // peel out old, but rewritten where clauses and results, and prepend before newWheres
  if ((Request)`from <{Binding ","}+ _> select <{Result ","}+ rs> where <{Expr ","}+ ws>` := req) {
    newResults = [ r | Result r <- rs ] + newResults;
    newWheres = [ w | Expr w <- ws ] + newWheres;
  }
  
  Query newQuery = buildQuery(newBindings, newResults, newWheres);
  return (Request)`<Query newQuery>`;
}

/*
Ok, this does not work, because we need to expand paths *the same way* if they're starting from the
same var: e.g. in, r.user.name r.user.age, both instances of r.user should be expanded
to a single where clause + binding: Person person_0 ... where r.user == person_0, person_0.name ... person_0.age

So an alternative is:
  for each var in the *current* (!) env, iterate over all relations its entity has,
  and eliminate all paths over it *at once*, 
  repeat until the env does not change anymore

*/

Request expandNavigation_(req:(Request)`from <{Binding ","}+ bs> select <{Result ","}+ rs> where <{Expr ","}+ ws>`, Schema s) {
  Env env = queryEnv(bs);
  
  int varId = 0;
  str newVar(str base) {
    str x = "<uncapitalize(base)>_<varId>";
    varId += 1;
    return x;
  }
  
  list[Binding] newBindings = [ b | Binding b <- bs ];
  
  // NB: empty, because they are rewritten
  list[Result] newResults = [];
  list[Expr] newWheres = [];
  
  
  solve (req) {
    req = visit (req) {
      case e:(Expr)`<VId x>.<{Id "."}+ fs>`: {
        list[str] fsList = [ "<f>" | Id f <- fs ];
        if (size(fsList) == 1) {
          insert e;
        }
        else {
        
         /*
  
		  if entity of x has relation (not attr/datatype f1 to entity y
		  x.f1.f2... => 
		    add Y $y binding, add to environment
		    add where clause x.f1 == $y, 
		    replace exp with $y.f2...
		    repeat
  
  		 */
  		 
          str entity = env["<x>"];
          str role = fsList[0];
          if (<entity, _, role, _, _, str target, _> <- s.rels) {
            str y = newVar(target);
            env[y] = target;
            newBindings += [ [Binding]"<target> <y>" ];
            newWheres += [ [Expr]"<x>.<role> == <y>" ];
            println("INSERTING: <y>.<intercalate(".", fsList[1..])>");
            insert [Expr]"<y>.<intercalate(".", fsList[1..])>";
          }
        }
      }
    }
  }
  
  // peel out old, but rewritten where clauses and results, and prepend before newWheres
  if ((Request)`from <{Binding ","}+ _> select <{Result ","}+ rs> where <{Expr ","}+ ws>` := req) {
    newResults = [ r | Result r <- rs ] + newResults;
    newWheres = [ w | Expr w <- ws ] + newWheres;
  }
  
  Query newQuery = buildQuery(newBindings, newResults, newWheres);
  return (Request)`<Query newQuery>`;
  
 
  
  // TODO change notation if into data type
  // replace paths with where clauses
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
