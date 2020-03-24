module lang::typhonql::mongodb::Insert2Mongo

import lang::typhonql::mongodb::DBCollection;

import lang::typhonql::TDBC;
import lang::typhonql::Expr;
import lang::typhonql::Script;
import lang::typhonql::Session
;
import lang::typhonml::Util;

import String;
import ParseTree;
import IO;


str mongoId() = "_id";


bool hasId({KeyVal ","}* kvs)
  = any((KeyVal)`@id: <Expr _>` <- kvs);


// Typechecker: nesting in Objects, only for containment in the same database.
// this form also assumes, it is not owned (so entity e == collection)
list[Step] insert2mongo((Request)`insert <EId e> {<{KeyVal ","}* kvs>}`, Schema s, Place p, str myId, Param myParam) {
  // abusing Field in params to obtain an ID from the Java side.
  
  Bindings myParams = (myId: myParam);
  
  DBObject obj = object([ keyVal2prop(kv) | KeyVal kv <- kvs ]
    + [ <mongoId(), placeholder(name=myId)> | !hasId(kvs) ]);

  return [step(p.name, mongo(insertOne(p.name, "<e>", pp(obj))), myParams)];
}

// TODO: need cardinality interpretation too

DBObject obj2dbObj((Expr)`<EId e> {<{KeyVal ","}* kvs>}`)
  = object([ keyVal2prop(kv) | KeyVal kv <- kvs ]);
   
DBObject obj2dbObj((Expr)`[<{Obj ","}* objs>]`)
  = array([ obj2dbObj((Expr)`<Obj obj>`) | Obj obj <- objs ]);

DBObject obj2dbObj((Expr)`[<{UUID ","}+ refs>]`)
  = array([ obj2dbObj((Expr)`<UUID ref>`) | UUID ref <- refs ]);

DBObject obj2dbObj((Expr)`<Bool b>`) = \value("<b>" == "true");

DBObject obj2dbObj((Expr)`<Int n>`) = \value(toInt("<n>"));

DBObject obj2dbObj((Expr)`<PlaceHolder p>`) = placeholder(name="<p>"[2..]);

DBObject obj2dbObj((Expr)`<UUID id>`) = \value("<id>"[1..]);

DBObject obj2DbObj((Expr)`<DateTime d>`) 
  = object([<"$date", \value(readTextValueString(#datetime, "<d>"))>]);


DBObject obj2dbObj((Expr)`<Real r>`) = \value(toReal("<r>"));

// todo: unescaping
DBObject obj2dbObj((Expr)`<Str x>`) = \value("<x>"[1..-1]);
  
Prop keyVal2prop((KeyVal)`<Id x>: <Expr e>`) = <"<x>", obj2dbObj(e)>;
  
Prop keyVal2prop((KeyVal)`@id: <UUID u>`) = <mongoId(), \value("<u>"[1..])>;
  
  
default DBObject obj2dbObj(Expr e) {
  throw "Unsupported expression in object literal notation: <e>";
}

