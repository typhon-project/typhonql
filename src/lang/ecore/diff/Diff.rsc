module lang::ecore::diff::Diff

import lang::ecore::diff::LCS;
import lang::ecore::Refs;

import Node;
import List;
import IO;
import Type;


@doc{A patch consists of a new root and a sequences of edits}
alias Patch
  = tuple[Id root, Edits edits];

@doc{Edits are operations attached to object identities.
This list should always contain all create()'s at the start,
destroy()'s at the end, and the rest in between.}
alias Edits
  = lrel[Id obj, Edit edit];

data Edit
  = put(str field, value val)
  | unset(str field)
  | ins(str field, int pos, value val)
  | del(str field, int pos)
  | create(str class) 
  | destroy() 
  ;
  
@doc{Compute map from identity to object node. NB: injections will not be in the map because of isObj.}  
map[Id, node] objectMap(node x) = ( getId(n): n | /node n := x, isObj(n) ); 

@doc{Construct a patch to (re)create the model `new`}
Patch model2patch(type[&T<:node] meta, &T<:node new) {
  m = objectMap(new);
  
  edits = [ <c, create(getClass(m[c]))> | Id c <- m ];
  edits += [ *init(meta, c, m[c]) | Id c <- m ];
  
  return <getId(new), edits>;
}

@doc{A patch is complete if all objects referred to are created and none are deleted} 
bool isComplete(Patch patch) {
  objs = { x | Id x <- patch.edits<0> } + {patch.root};
  created = { x | <Id x, create(_)> <- patch.edits };
  deleted = { x | <Id x, destroy()> <- patch.edits };
  return objs == created && deleted == {};
}

@doc{Compute the difference between `old` and `new` in the form of a patch}
Patch diff(type[&T<:node] meta, &T old, &T new) {
  // TODO: we can save some traversals through fusion.
  // TODO: assert that there are no injections in the object maps
  m1 = objectMap(old);
  m2 = objectMap(new);
  
  edits = [ <c, create(getClass(m2[c]))> | Id c <- m2, c notin m1 ];
  edits += [ *init(meta, c, m2[c]) | Id c <- m2, c notin m1 ];
  edits += [ *diff(meta, x, m1[x], m2[x]) | Id x <- m1, x in m2 ];
  edits += [ <d, destroy()> | Id d <- m1, d notin m2 ];
  
  return <getId(new), edits>;
}

@doc{Compute the required edits to initialize `id` according to `new`}
Edits init(type[&T<:node] meta, Id id, node new) {
  Symbol s = getType(new);
  str c = getName(new);
  
  Edits edits = [];
  
  ps = getParams(meta, s, c);
  newKids = getChildren(new);
  edits += [ *initKid(id, newKids[i], ps[i]) | int i <- [0..size(ps)] ];
  
  kws = getKwParams(meta, s, c);
  newKws = getKeywordParameters(new);
  edits += [ *initKid(id, newKws[fld], fld) | str fld <- kws, fld != "uid", fld in newKws ];

  return edits;
}

@doc{Lists are initialized using a sequence of `ins` operations.}
Edits initKid(Id id, list[value] v, str field) 
  = [ <id, ins(field, i, primOrId(v[i]))> | int i <- [0..size(v)] ];

@doc{Other attributes are mapped to `put` edits}
default Edits initKid(Id id, value v, str field)
  = [<id, put(field, primOrId(v))>];


@doc{Compute the set of differences for two identified model elements of the same type}
Edits diff(type[&T<:node] meta, Id id, node old, node new) {
  assert getClass(old) == getClass(new);
  
  Symbol s = getType(old);
  str c = getName(old);
  
  Edits edits = [];
  
  ps = getParams(meta, s, c);
  
  oldKids = getChildren(old);
  newKids = getChildren(new);
  edits += [ *diffKid(id, oldKids[i], newKids[i], ps[i]) | int i <- [0..size(ps)] ];  
  
  kws = getKwParams(meta, s, c);
  oldKws = getKeywordParameters(old);
  newKws = getKeywordParameters(new);
  for (str field <- kws, field != "uid") {
    if (field in oldKws, field in newKws) {
      edits += diffKid(id, oldKws[field], newKws[field], field);
    }
    else if (field in oldKws) {
      edits += [<id, unset(field)>];
    }
    else if (field in newKws) {
      edits += [<id, put(field, primOrId(newKws[field]))>];
    }
  }
  
  return edits;
}

@doc{Compute the difference between two "kids" (features, fields, properties, ...) of `id`}
Edits diffKid(Id id, value oldKid, value newKid, str field) {
  if (refEq(newKid, oldKid)) {
    return [];
  }

  if (list[value] xs := oldKid, list[value] ys := newKid) {
    mx = lcsMatrix(xs, ys, refEq);
    ds = getDiff(mx, xs, ys, size(xs), size(ys), refEq);
    int offset = 0;
    return for (Diff d <- ds) {
      switch (d) {
        case add(value v, int pos): {
          append <id, ins(field, pos, primOrId(v))>;
          offset += 1;
          
         }
        case remove(_, int pos): { 
          append <id, del(field, pos + offset)>;
          offset -= 1;
        }
      }
    }
  }

   // attributes and refs
  return [<id, put(field, primOrId(newKid))>];
}

@doc{Convert an arbitrary value to either an Id or a primitive value}
value primOrId(value v) {
  if (ref(Id x) := v) {
    return x;
  }
  if (node n := v, hasId(n)) {
    return getId(n);
  }
  return v;
}

bool isInjectionProd(Production p) = label("_inject", _) <- p.kwTypes;
  
// TODO: move to utils
list[str] getParams(type[&T<:node] meta, Symbol s, str c)
  = [ fld | p:cons(label(c, s), list[Symbol] ps, _, _) <- meta.definitions[s].alternatives, label(str fld, _) <- ps, !isInjectionProd(p) ];

list[str] getKwParams(type[&T<:node] meta, Symbol s, str c)
  = [ fld | p:cons(label(c, s), _, list[Symbol] kws, _) <- meta.definitions[s].alternatives, label(str fld, _) <- kws, !isInjectionProd(p) ];
  