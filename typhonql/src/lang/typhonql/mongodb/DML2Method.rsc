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

lrel[str, CollMethod] compile2mongo((Request)`insert <{Obj ","}* objs>`, Schema s) {
  //objList = flattenForMongoDB(objs);
  // assumes flattening as per partitioning
  
  map[str, Obj] env = ( lookupId(obj.keyVals): obj | Obj obj <- objs ); 
  
  return [ <"<obj.entity>", \insert( [ obj2dbObj((Expr)`<Obj obj>`, env, s) ])>  | Obj obj <- objs  ] ;
}

str typhonId() = "_id";

// TODO: need cardinality interpretation too

DBObject obj2dbObj((Expr)`<EId e> {<{KeyVal ","}* kvs>}`, map[str,Obj] env, Schema s)
  = object([ keyVal2prop(kv, "<e>", env, s) | KeyVal kv <- kvs ]);
   
DBObject obj2dbObj((Expr)`[<{Obj ","}* objs>]`, map[str, Obj] env, Schema s)
  = array([ obj2dbObj((Expr)`<Obj obj>`, env, s) | Obj obj <- objs ]);



DBObject obj2dbObj((Expr)`<Bool b>`, str from, str fld, map[str, Obj] env, Schema s) = \value("<b>" == "true");

DBObject obj2dbObj((Expr)`<Int n>`,  str from, str fld, map[str, Obj] env, Schema s) = \value(toInt("<n>"));

DBObject obj2dbObj((Expr)`<Real r>`,  str from, str fld, map[str, Obj] env, Schema s) = \value(toReal("<r>"));

// todo: unescaping
DBObject obj2dbObj((Expr)`<Str x>`, str from, str fld, map[str, Obj] env, Schema s) = \value("<x>"[1..-1]);

DBObject obj2dbObj((Expr)`<UUID u>`, str from, str fld, map[str, Obj] env, Schema s) {
 // if it is a containment (canonical) lookup in env and inline.
 if (<from, _, fld, _, _, str to, true> <- s.rels) {
   if (<Place p1, from> <- s.placement, <Place p2, to> <- s.placement, p1 == p2) {
     str id = "<u>"[1..];
     return obj2dbObj(env[id], env, s);
   }
 }
 return \value("<u>");
}

  
Prop keyVal2prop((KeyVal)`<Id x>: <Expr e>`, str from, map[str, Obj] env, Schema s)
  = <"<x>", obj2dbObj(e, from, "<x>", env, s)>;
  
Prop keyVal2prop((KeyVal)`@id: <UUID u>`, str from, map[str, Obj] env, Schema s)
  = <typhonId(), \value("<u>"[1..])>;
  
  
  
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
