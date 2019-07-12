module lang::typhonql::mongodb::DML2Method

import lang::typhonql::mongodb::DBCollection;
import lang::typhonql::TDBC;
import lang::typhonql::Expr;
import lang::typhonml::Util;
import lang::typhonql::util::Objects;

import String;
import ParseTree;

/*
How to determine whether an entity becomes a collection
or anonymously nested?

I guess if it's contained, and there are no incoming xrefs to it the entity, otherwise, we need a reference identifier


For now we assume that contained things are literally gonna be contained in mongo

So for an arbitrary lists of Obj's we need to normalize them to have contained things
be literally contained, and not using the cross ref feature; for now however, we assume the 
user does not do that.


*/

map[str, CollMethod] compile2mongo((Request)`insert <{Obj ","}* objs>`, Schema s) {
  objList = flattenForMongoDB(objs);
  IdMap ids = makeIdMap(objList);
  
  // TODO: unflatten to get native nesting
  
  // ugh this is ugly...
  return ( e: \insert([ obj2dbObj((Expr)`<Obj obj>`, ids) | obj:(Obj)`@<VId x> <EId _> {<{KeyVal ","}* _>}` <- objList
            , str name := "<x>", <name, e, _> <- ids ]) | str e <- ids<1> );
}

str typhonId() = "@id";

// TODO: need cardinality interpretation to

DBObject obj2dbObj((Expr)`@<VId x> <EId e> {<{KeyVal ","}* kvs>}`, IdMap ids)
  = object([<typhonId(), \value(myId)>] + [ keyVal2prop(kv, ids) | KeyVal kv <- kvs ])
  when <_, str myId> <- ids["<x>"];
   
DBObject obj2dbObj((Expr)`<EId e> {<{KeyVal ","}* kvs>}`, IdMap ids)
  = object([ keyVal2prop(kv, ids) | KeyVal kv <- kvs ]);

DBObject obj2dbObj((Expr)`[<{Obj ","}* objs>]`, IdMap ids)
  = array([ obj2dbObj((Expr)`<Obj obj>`, ids) | Obj obj <- objs ]);

DBObject obj2dbObj((Expr)`<Bool b>`, IdMap ids) = \value("<b>" == "true");

DBObject obj2dbObj((Expr)`<Int n>`, IdMap ids) = \value(toInt("<n>"));

// todo: unescaping
DBObject obj2dbObj((Expr)`<Str s>`, IdMap ids) = \value("<s>"[1..-1]);

DBObject obj2dbObj((Expr)`<VId x>`, IdMap ids) = \value(uuid)
  when <_, str uuid> <- ids["<x>"];
  
Prop keyVal2prop((KeyVal)`<Id x>: <Expr e>`, IdMap ids)
  = <"<x>", obj2dbObj(e, ids)>;
  
Prop keyVal2prop((KeyVal)`@id: <Expr e>`, IdMap ids)
  = <typhonId(), obj2dbObj(e, ids)>;
  
  
  
default DBObject obj2dbObj(Expr e, IdMap ids) {
  throw "Unsupported expression in object literal notation: <e>";
}


list[Obj] flattenForMongoDB({Obj ","}* objs) {
  int i = 0;
  VId newLabel() {
    VId x =[VId]"obj_<i>";
    i += 1;
    return x;
  }
  
  list[Obj] result = [];
  
  
  // TODO: assign ids to nested object as well to trigger id generation in the idmap
  // top-levels
  for ((Obj)`<EId e> {<{KeyVal ","}* kvs>}` <- objs) {
    VId l = newLabel();
    result += [(Obj)`@<VId l> <EId e> {<{KeyVal ","}* kvs>}`]; 
  }

  result += [ obj | obj:(Obj)`@<VId l> <EId e> {<{KeyVal ","}* kvs>}` <- objs ];
  
  return result;
}
