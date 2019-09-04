module lang::typhonql::util::Objects

import lang::typhonql::Expr;
import lang::typhonql::util::UUID;
import IO;

/*

Utility module to manipulate Object Literals (see lang::typhonql::Expr).

*/

alias IdMap = lrel[str name, str entity, str uuid];


str lookupId({KeyVal ","}* kvs) {
  if ((KeyVal)`@id: <UUID uuid>` <- kvs) {
    return "<uuid>"[1..];
  }
  throw "No @id field found in <kvs>";
}
  
bool hasAssignedId({KeyVal ","}* kvs) = (KeyVal)`@id: <Expr _>` <- kvs;

// TODO: flattening of lists *is* SQL specific...

@doc{Flatten possibly nested objs to a list of labeled object literals
where nesting is represented using references. Lists of nested objects are
flattened to repeated field entries.}
list[Obj] flatten({Obj ","}* objs, bool doFlattening = true) {
  int i = 0;
  VId newLabel() {
    VId x =[VId]"obj_<i>";
    i += 1;
    return x;
  }
  
  list[Obj] result = [];
  
  if (doFlattening) {
    objs = visit (objs) {
      case {KeyVal ","}* kvs => flattenLists(kvs)
    }
  }
  
  // NB: bottom-up is essential here
  objs = bottom-up visit (objs) {
    case (KeyVal)`<Id x>: <EId e> {<{KeyVal ","}* kvs>}`: {
      VId l = newLabel();
      result += [(Obj)`@<VId l> <EId e> {<{KeyVal ","}* kvs>}`]; 
      insert (KeyVal)`<Id x>: <VId l>`;  
    }
  } 
  
  // top-levels
  for ((Obj)`<EId e> {<{KeyVal ","}* kvs>}` <- objs) {
    VId l = newLabel();
    result += [(Obj)`@<VId l> <EId e> {<{KeyVal ","}* kvs>}`]; 
  }

  result += [ obj | obj:(Obj)`@<VId l> <EId e> {<{KeyVal ","}* kvs>}` <- objs ];
  
  return result;
}

{KeyVal ","}* flattenLists({KeyVal ","}* kvs) {
  list[KeyVal] lst = [];
  for (KeyVal kv <- kvs) {
    if ((KeyVal)`<Id x>: [<{Obj ","}* objs>]` := kv) {
      lst += [ (KeyVal)`<Id x>: <Obj obj>` | Obj obj <- objs ];
    }
    else {
      lst += [kv];
    }
  }
  return buildKeyVals(lst);
}

{KeyVal ","}* buildKeyVals(list[KeyVal] lst) {
  Obj obj = (Obj)`Foo {}`;
  for (KeyVal kv <- lst) {
    if ((Obj)`Foo {<{KeyVal ","}* kvs>}` := obj) {
      obj = (Obj)`Foo {<{KeyVal ","}* kvs>, <KeyVal kv>}`;
    }
  }
  return obj.keyVals;
}


IdMap makeIdMap(list[Obj] objs) 
  = [ <"<vid>", "<entity>", makeUUID()> | (Obj)`@<VId vid> <EId entity> {<{KeyVal ","}* _>}` <- objs ];



