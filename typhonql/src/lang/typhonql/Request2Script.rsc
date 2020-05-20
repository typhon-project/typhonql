module lang::typhonql::Request2Script


import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::Script;
import lang::typhonql::Session;
import lang::typhonql::TDBC;
import lang::typhonql::Order;
import lang::typhonql::Normalize;

import lang::typhonql::Insert2Script;
import lang::typhonql::Update2Script;
import lang::typhonql::Delete2Script;
import lang::typhonql::Query2Script;
import lang::typhonql::DDL2Script;


import lang::typhonql::relational::SQL;
import lang::typhonql::relational::Util;
import lang::typhonql::relational::SQL2Text;
import lang::typhonql::relational::Query2SQL;

import lang::typhonql::mongodb::Query2Mongo;
import lang::typhonql::mongodb::DBCollection;

import lang::typhonql::util::Log;

import IO;
import List;

/*

TODO:

- modularize using pattern-based dispatch
- use toRole matching to "" to determine the canonical relation in case of non-ownership
- clean-up the PARAM string passing
- custom data type expansion
- NLP hooks

*/


bool hitsBackend((Request)`<Query q>`, Place p, Schema s) 
  = ( false | it || (<p, "<b.entity>"> in s.placement) | Binding b <- q.bindings );


Script request2script(Request r, Schema s, Log log = noLog) {
  log("REQ: <r>");


  switch (r) {

    case (Request)`<Query q>`: {
      list[Place] order = orderPlaces(r, s);
      r = expandNavigation(inferKeyValLinks(addWhereIfAbsent(r), s), s);
      log("NORMALIZED: <r>");
      Script scr = script([ *compileQuery(restrict(r, p, order, s), p, s, log = log) 
         | Place p <- order, hitsBackend(r, p, s)]);
      scr.steps += [read(results2paths(r.qry.selected, queryEnv(r.qry), s))];
      return scr;
    }

    case (Request)`update <EId e> <VId x> set {<{KeyVal ","}* kvs>}`: {
      return request2script((Request)`update <EId e> <VId x> where true set {<{KeyVal ","}* kvs>}`, s);
    }

    case (Request)`update <EId e> <VId x> where <{Expr ","}+ ws> set {<{KeyVal ","}* kvs>}`:
      return update2script(r, s);


    case (Request)`delete <EId e> <VId x>`: {
	  return request2script((Request)`delete <EId e> <VId x> where true`, s);
	}

	case (Request)`delete <EId e> <VId x> where <{Expr ","}+ ws>`:
	  return delete2script(r, s);

    case (Request)`insert <EId e> { <{KeyVal ","}* kvs> }`:
       return insert2script(r, s); 
    
    default: 
      //throw "Unsupported request: `<r>`";
      return ddl2script(r, s);
  }
}



void smokeScript() {
  s = schema({
    <"Person", zero_many(), "reviews", "user", \one(), "Review", true>,
    <"Person", zero_many(), "cash", "owner", \one(), "Cash", true>,
    <"Person", \one(), "SomeStuff__", "", \one(), "SomeStuff", true>,
    <"Review", \one(), "user", "reviews", \zero_many(), "Person", false>,
    <"Review", \one(), "comment", "owner", \zero_many(), "Comment", true>,
    <"Comment", zero_many(), "replies", "owner", \zero_many(), "Comment", true>
  }, {
    <"Person", "name", "text">,
    <"Person", "age", "int">,
    <"SomeStuff", "photo", "text">,
    <"SomeStuff", "bitcoin", "text">,
    <"Cash", "amount", "int">,
    <"Review", "text", "text">,
    <"Comment", "contents", "text">,
    <"Reply", "reply", "text">
  },
  placement = {
    <<cassandra(), "Stuff">, "SomeStuff">,
    <<sql(), "Inventory">, "Person">,
    <<sql(), "Inventory">, "Cash">,
    <<mongodb(), "Reviews">, "Review">,
    <<mongodb(), "Reviews">, "Comment">
  }
  );

  void smokeIt(Request q) {
    println("REQUEST: `<q>`");
    iprintln(request2script(q, s));
  }




  smokeIt((Request)`delete Review r`);


  smokeIt((Request)`delete Review r where r.text == "Bad"`);

  smokeIt((Request)`delete Comment c where c.contents == "Bad"`);

  smokeIt((Request)`delete Person p`);

  smokeIt((Request)`delete Person p where p.name == "Pablo"`);

  smokeIt((Request)`update Person p set {name: "Pablo"}`);

  smokeIt((Request)`update Person p set {name: "Pablo", age: 23}`);


  smokeIt((Request)`update Person p where p.name == "Pablo" set {reviews +: [#abc, #cde]}`);

  smokeIt((Request)`update Person p where p.name == "Pablo" set {reviews -: [#abc, #cde]}`);

  smokeIt((Request)`update Person p where p.name == "Pablo" set {reviews: [#abc, #cde]}`);

  smokeIt((Request)`update Review r set {text: "bad"}`);

  smokeIt((Request)`update Review r where r.text == "Good" set {text: "Bad"}`);

  smokeIt((Request)`update Person p set {name: "Pablo", cash: [#abc, #cde]}`);

  smokeIt((Request)`update Person p set {name: "Pablo", cash +: [#abc, #cde]}`);

  smokeIt((Request)`update Person p set {name: "Pablo", cash -: [#abc, #cde]}`);

  smokeIt((Request)`update Person p where p.name == "Pablo" set {reviews -: [#abc, #cde]}`);

  smokeIt((Request)`update Person p where p.name == "Pablo" set {reviews +: [#abc, #cde], reviews -: [#xyz]}`);

  smokeIt((Request)`update Person p where p.name == "Pablo" set {reviews -: [#abc, #cde], name: "Pete"}`);

  smokeIt((Request)`update Person p where p.name == "Pablo" set {reviews -: [#abc, #cde], age: 32, name: "Bla"}`);

  smokeIt((Request)`update Person p where p.name == "Pablo" set {cash: [#dollar]}`);
  smokeIt((Request)`update Person p where p.name == "Pablo" set {cash +: [#dollar]}`);
  smokeIt((Request)`update Person p where p.name == "Pablo" set {cash -: [#dollar]}`);

  smokeIt((Request)`update Cash c where c.amount \> 0 set {owner: #pablo}`);

  smokeIt((Request)`update Cash c where c.@id == #dollar  set {owner: #pablo}`);

  smokeIt((Request)`update Comment c where c.@id == #stupid set { replies: [#abc1, #cdef2] }`);

  smokeIt((Request)`update Comment c where c.@id == #stupid set { replies +: [#abc1, #cdef2] }`);

  smokeIt((Request)`update Comment c where c.@id == #stupid set { replies -: [#abc1, #cdef2] }`);



  smokeIt((Request)`delete Person p where p.name == "Pablo"`);

  smokeIt((Request)`insert Person {name: "Pablo", age: 23}`);
  smokeIt((Request)`insert Person {name: "Pablo", age: 23, reviews: #abc, reviews: #cdef}`);

  smokeIt((Request)`insert Review {text: "Bad"}`);

  smokeIt((Request)`insert Person {name: "Pablo", age: 23, @id: #pablo}`);

  smokeIt((Request)`insert Review {text: "Bad", user: #pablo}`);


  smokeIt((Request)`insert Person {name: "Pablo", age: 23}`);
  smokeIt((Request)`insert Person {name: "Pablo", age: 23, reviews: [#abc, #cdef]}`);

  smokeIt((Request)`insert Review {text: "Bad", user: #pablo}`);

  smokeIt((Request)`update Person p set {name: "Pablo"}`);

  smokeIt((Request)`update Person p set {name: "Pablo", age: 23}`);



  smokeIt((Request)`from Person p, Review r select r.text, p.name where p.name == "Pablo", p.reviews == r`);

  smokeIt((Request)`from Person p, Review r select r.text, p.name where p.name == "Pablo", p.reviews == r`);

  smokeIt((Request)`from Person u, Review r select r where r.user == u, u.name == "Pablo"`);

  smokeIt((Request)`from Person p, Review r select r.text, p.name where p.name == "Pablo", p.reviews == r`);

  smokeIt((Request)`from Person p, Cash c select p.name where p.name == "Pablo", p.cash == c, c.amount \> 0`);


  smokeIt((Request)`from Person u, Review r select u.name, r.user where u.reviews == r, r.text == ""`);

  smokeIt((Request)`from Person p select p.reviews where p == #victor`);

  smokeIt((Request)`insert Person {name: "Pablo", age: 23, photo: "hello"}`);
  
  smokeIt((Request)`insert Person {name: "Pablo", age: 23, photo: "hello", bitcoin: "bla"}`);
 
 
  smokeIt((Request)`delete Review r`);

  smokeIt((Request)`delete Review r where r.text == "Bad"`);

  smokeIt((Request)`delete Comment c where c.contents == "Bad"`);

  smokeIt((Request)`delete Person p`);

  smokeIt((Request)`delete Person p where p.name == "Pablo"`);
 
  
  smokeIt((Request)`from Person p, Review r select r.text, p.name where p.name == "Pablo", p.reviews == r`);

  smokeIt((Request)`from Person p, Review r select r.text, p.name where p.name == "Pablo", p.reviews == r`);

  smokeIt((Request)`from Person u, Review r select r where r.user == u, u.name == "Pablo"`);

  smokeIt((Request)`from Person p, Review r select r.text, p.name where p.name == "Pablo", p.reviews == r`);

  smokeIt((Request)`from Person p, Cash c select p.name where p.name == "Pablo", p.cash == c, c.amount \> 0`);


  smokeIt((Request)`from Person u, Review r select u.name, r.user where u.reviews == r, r.text == ""`);

  smokeIt((Request)`from Person p select p.reviews where p == #victor`);

  smokeIt((Request)`from Person p select p.photo where p == #victor`);

  smokeIt((Request)`from Person p select p.photo, p.bitcoin where p == #victor`);

    
}
