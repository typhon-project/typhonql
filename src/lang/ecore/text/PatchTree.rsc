module lang::ecore::text::PatchTree

import lang::ecore::text::Tree2Model;
import lang::ecore::text::Grammar2Ecore;
extend lang::ecore::text::Paths;

import lang::ecore::diff::Diff;
import lang::ecore::Refs;

import ParseTree;

import Type;
import String;
import Set;
import IO;

/*
TODOS
- fix locs during the unflatten phase.
- merge flatten, and layout prototype derivation in one traversal
*/



@doc{Convert an (abtract) model into a concrete parse tree (inventing layout).}
&T<:Tree model2tree(type[&T<:Tree] tt, type[&M<:node] meta, &M<:node model, Tree(type[&U<:Tree], str) parse, map[Production, Tree] protos = ()) 
  = patch2tree(tt, model2patch(meta, model), parse, protos = protos);


@doc{Convert a complete patch into a concrete parse tree}
&T<:Tree patch2tree(type[&T<:Tree] tt, Patch patch, Tree(type[&U<:Tree], str) parse, map[Production, Tree] protos = ()) {
  assert isComplete(patch): "patches need to be complete for creating a tree";

  trees = ( obj: prod2tree(findProd(tt, class), protos) | <Id obj, create(str class)> <- patch.edits );
  trees = patchTrees(tt, trees, patch, parse, protos = protos);
  trees = unflatten(patch.root, trees);
  root = trees[patch.root];
  return typeCast(tt, resolveTree(root, root, trees)); 
}

/*
 * The basic idea of patching a tree according to a diff is:
 * - the old tree is "flattened" into a map from Id to Tree where containment and cross refs are simulated with proxy trees
 * - new trees created by the patch are added to the map with synthesized trees based on prototypes (if available) with placeholders
 * - the map is then modified according to the edits contained in the patch
 * - "unflatten" reconstructs the root by recursively inserting back actual trees for the "contain" proxies.
 * - resolve solves paths for finding the identifier for the cross-ref proxies.
 */


@doc{Patch an old tree `pt` according to `patch` and the origin relation between objects and (sub) parse trees}
&T<:Tree patchTree(type[&T<:Tree] tt, &T<:Tree pt, Patch patch, Org origins, Tree(type[&U<:Tree], str) parse) {
  Tree old = pt;
  if (pt has top) {
    old = pt.top;
  }

  // FIXME: get rid of this, make origins directly of the right form.
  rel[Id, loc] orgs = { <k, origins[k]> | Id k <- origins };

  protos = layoutPrototypes(old);

  // turn the tree into a flat map indexed by Id. 
  trees = ( obj: flatten(t, old, orgs) | /Tree t := old, mapsToObject(t),  loc l := t@\loc, <Id obj, l> <- orgs )
  // note, we "just" create placeholders here, we don't know the exact prods yet, only after init.
        + ( obj: prod2tree(findProd(tt, class), protos) | <Id obj, create(str class)> <- patch.edits );
  
  trees = patchTrees(tt, trees, patch, parse, protos=protos);
  
  // connect all containment references to get proper trees again
  trees = unflatten(patch.root, trees);
  root = trees[patch.root];
  
  // restore layout around the top
  if (pt has top) {
    root = addLoc(appl(pt.prod, [pt.args[0], trees[patch.root], pt.args[2]]), pt);
  }
  
  return typeCast(tt, resolveTree(root, root, trees)); 
}

@doc{Construct map from "object" and regular productions to trees with layout or separator information}
map[Production, Tree] layoutPrototypes(Tree t)
  = ( sub.prod: sub | /Tree sub := t, mapsToObject(sub) )
  + ( reg.prod: reg | /Tree reg := t, reg has prod, reg.prod is regular, size(reg.args) > 1 );


@doc{Check if a tree should correspond to an object}
bool mapsToObject(Tree t) = t has prod && t.prod.def is label && t@\loc?;

@doc{Apply the patch to a flattened representation of a parse tree}
map[Id, Tree] patchTrees(type[&T<:Tree] tt, map[Id, Tree] trees, Patch patch, Tree(type[&U<:Tree], str) parse, map[Production, Tree] protos = ()) {
  
  map[tuple[Id, str], list[Tree]] sepCache = ();
  
  tuple[Tree,list[Tree]] getListAndSeps(Id obj, str field, Tree lst) {
    if (<obj, field> notin sepCache) {
      sepCache[<obj,field>] = getSeparators(lst, protos=protos);
    }
    return <lst, sepCache[<obj,field>]>;
  }
  
  for (<Id obj, Edit edit> <- patch.edits, edit has field) {
     Tree t = trees[obj];
     int idx = getFieldIndex(t.prod, edit.field);
     
     // if field is not found, we  promote trees[obj] to new production that has the field.
     // todo: what if we don't find any?
     if (idx == -1) {
       assert t.prod is prod;
       
       assignedFields = ( f: t.args[i] | int i <- [0..size(t.prod.symbols)], label(str f, _) := t.prod.symbols[i], !isPlaceholder(t.args[i]) );
                                      
       newProd = findSmallestProdHavingFields(tt, prod.def.name, f<0> + {field});
       
       newTree = setArgs(prod2tree(newProd, protos), assignedFields);
       
       trees[obj] = newTree;                                
     }
     
     switch (edit) {
       //case unset(str field): {
       //  trees[obj] = setArg(t, idx, null());
       //}
     
       case put(str field, value v): {
         Tree newVal = valToTree(v, tt, t.prod, field, t.prod.symbols[idx], parse);
         trees[obj] = setArg(t, idx, newVal);
       }
       
       case ins(str field, int pos, value v): {
         <lst, seps> = getListAndSeps(obj, field, t.args[idx]);
        
         lst = insertList(lst, pos, valToTree(v, tt, t.prod, field, lst.prod.def.symbol, parse), 
                  seps);
         
         // check for empty layout & reuse layout that is before.
         if ("<t.args[idx+1]>" == "") {
           t = setArg(t, idx + 1, t.args[idx-1]);
         }

         trees[obj] = setArg(t, idx, lst);
         //println("T = `<trees[obj]>`");
       }

       case del(str field, int pos): {
         <lst, seps> = getListAndSeps(obj, field, t.args[idx]);
         trees[obj] = setArg(t, idx, removeList(lst, pos, seps));
       }

     }
  }
   
  // due to promotion/template picking, some trees might have fewer assigned
  // fields after applying the patch, so could be better represented using
  // different productions of the same type. So here we demote productions
  // if possible.
  for (Id x <- trees) {
    old = trees[x];
    assignedFields = ( f: old.args[i] | int i <- [0..size(old.prod.symbols)], label(str f, _) := old.prod.symbols[i], !isPlaceholder(old.args[i]) );

    newProd = findSmallestProdHavingFields(tt, old.prod.def.name, assignedFields<0>);
    
    if (newProd != old.prod) {
      template = prod2tree(newProd, protos);
      newTree = setArgs(template, assignedFields);
      trees[x] = newTree;
    }    
  } 

  return trees;   
}

Tree flatten(t:appl(Production p, list[Tree] args), Tree root, rel[Id, loc] orgs) 
  = addLoc(appl(p, [ flattenArg(args[i], t, root, p.symbols[i], orgs) | int i <- [0..size(args)] ]), t);
  
Tree flattenArg(a:appl(prod(label(_, _), _, _), _), Tree parent, Tree root, Symbol s, rel[Id, loc] orgs) 
  = contain(obj)
  when loc l := a@\loc, <Id obj, l> <- orgs;

Tree flattenArg(a:appl(p:prod(_, _, _), _), Tree parent, Tree root, label(str field, Symbol _), rel[Id, loc] orgs) 
  = refer(path, deref(root, substBindings(path, treeEnv(parent)), orgs))
  when <field, _, str path> <- prodRefs(parent.prod);

Tree flattenArg(a:appl(p:regular(Symbol reg), list[Tree] args), Tree parent, Tree root, Symbol s, rel[Id, loc] orgs)
  =  addLoc(appl(p, [ flattenArg(elt, a, root, reg.symbol, orgs) | Tree elt <- args]), a);

default Tree flattenArg(Tree a, Tree parent, Tree root, Symbol s, rel[Id, loc] orgs) = a;

lrel[str, value] treeEnv(Tree t)
  = [ <fld, t.args[getFieldIndex(t.prod, fld)]> | label(str fld, _) <- t.prod.symbols ];


Tree valToTree(value v, type[&T<:Tree] tt, Production p, str field, Symbol s, Tree(type[&U<:Tree], str) parse) {
  switch (v) {
    case null():
      // todo: if there's something already in the tree, reuse that
      // so that user's partial ids for references are not deleted.
      return placeholder(s, field);
    
    case Id x: {
      if (<field, _, str path> <- prodRefs(p)) {
        return refer(path, x);
      }
      return contain(x);
    }
    
    case bool b: {
      if  (label(_, opt(lit(str l))) := s) {
        return appl(regular(s), [ char(i) | b, int i <- chars(l) ]);
      }
      fail;
    }
    
    default: {
      Symbol nt = (s is label ? s.symbol : s);
      src = "<v>";
      if (src == "") {
        return placeholder(nt, field);
      }
      return parse(typeCast(#type[&T<:Tree], type(nt, tt.definitions)), src);
    }
  } 
}
  

/*
 * Flattening of trees depends on inserting "fake" tree nodes capturing
 * containment and cross reference relations. These trees contain the
 * referenced Ids of the objects. During unflattening, the new tree is constructed
 * by inserting back the referenced trees (for containment) or identifiers 
 * for cross references.
 */

Production containProd(Id id) = prod(lit("CONTAIN"), [], {\tag("id"(id))}); 
Production referProd(str path, value x) =  prod(lit("REF"), [], {\tag("path"(path, x))});

Id containedId(appl(prod(lit("CONTAIN"), [], {\tag("id"(Id x))}), _)) = x;

Tree contain(Id id) 
  = appl(containProd(id), [ char(i) | int i <- chars("CONTAIN") ]);

Tree refer(str path, value x) 
  = appl(referProd(path, x), [ char(i) | int i <- chars("REF") ]);


@doc{Unflatten reconstructs the tree identified by `x` using the flat map representation `objs`}
map[Id, Tree] unflatten(Id x, map[Id, Tree] objs) {
  
  args = for (Tree a <- objs[x].args) {
    if (!(a has prod)) {
      append a;
      continue;
    }
    switch (a.prod) {
      case prod(lit("CONTAIN"), [], {\tag("id"(Id y))}): {
        objs = unflatten(y, objs);
        append objs[y];
      }
       
      case regular(_): {
        lstArgs = for (Tree elt <- a.args) {
          if (!(elt has prod)) { append elt; continue; }
          switch (elt.prod) {
             case prod(lit("CONTAIN"), [], {\tag("id"(Id y))}): {
		        objs = unflatten(y, objs);
		        append objs[y];
             }
             
             default: append elt;
          }
        }
        append addLoc(appl(a.prod, lstArgs), a);
      }
        
      default:
        append a;
    }
  }
  objs[x] = addLoc(appl(objs[x].prod, args), objs[x]);
  return objs;
}

@doc{Resolve replaces the fake cross-ref nodes with actual identifiers found with solvePath}
Tree resolveTree(Tree t, Tree root, map[Id, Tree] objs) {
  if (appl(_, _) !:= t) {
    return t;
  }
  
  env = ();
  
  int i = 0;
  args = for (Tree a <- t.args) {
    // if a is a crossref (e.g., "initial"), then we solve for the key value
    if (a has prod, prod(lit("REF"), [], {\tag("path"(str path, value val))}) := a.prod)  {
      Symbol s = t.prod.symbols[i];
      str fld = s.name; // assume labeled
      if (Id x := val) {
        try {
          env += solvePath(root, path, (), objs, x);
          append a; // for now, substituted below.
        }
        catch InvalidArgument(_, _): {
          append placeholder(s, fld);
        }
        
      }
      else {
        // null
        append placeholder(s, fld);
      }
    }
    else {
      append resolveTree(a, root, objs);
    } 
    i += 1;     
  }
  
  for (str fld <- env) {
    int idx = getFieldIndex(t.prod, fld);
    args[idx] = env[fld];
  }

  return addLoc(appl(t.prod, args), t);
}


@doc{Deref finds the target object of an identifier by dereferencing a path}
value deref(Tree t, str path, rel[Id, loc] orgs) {
  try {
    Tree trg = deref(t, parsePath(path));
    if (loc l := trg@\loc, <Id x, l> <- orgs) {
      return x;
    }
    return null();
  }
  catch value _: {
    return null();
  } 
}

@doc{Underef finds identifiers for cross references, given a path across the containment hierarchy}
map[str, Tree] solvePath(Tree tree, str path, map[str,Tree] env, map[Id, Tree] objs, Id target) 
  = solvePath(tree, parsePath(path), env, objs, target);



@doc{A placeholder production is a synthesized production for syntax "<" Id ":" NT ">"}
Production placeholderProd(Symbol s, Symbol id = lex("Id"))
  = prod(s, [lit("\<"), id, lit(":"), lit(symbolName(s)), lit("\>") ], 
       {\tag("placholder"())});


bool isPlaceholder(Production p)
  = p has attributes && \tag("placholder"()) <- p.attributes;

bool isPlaceholder(Tree t) = isPlaceholder(t.prod);


// the result cannot be used to parse (yet; bug in Rascal)
type[&T<:Tree] addPlaceholderProds(type[&T<:Tree] tt, Symbol id = lex("Id")) {
  map[Symbol, Production] defs = tt.definitions;
  for (Symbol s <- defs, s is lex || s is sort) {
    defs[s].alternatives += {placeholderProd(s, id = id)};
  }
  if (type[&T<:Tree] tt2 := type(tt.symbol, defs)) {
    return tt2;
  }
  //return typeCast(#type[&T<:Tree], type(tt.symbol, defs));
}


Tree placeholder(Symbol s, str field) {
  if (s is opt || s is \iter-star || s is \iter-star-seps) {
    return appl(regular(s), []);
  }
  if (s is \iter-seps || s is iter) {
    // TODO: why not generate a single element here?
    // (if so, currently it will be part of the list for new elements always...)
    return appl(regular(s), []);
  }
  str src = "\<<field>:<symbolName(s)>\>";
  return appl(placeholderProd(s), [ char(i) | int i <- chars(src) ]);
}
  
str symbolName(sort(str n)) = n;

str symbolName(lex(str n)) = n;

str symbolName(\opt(Symbol s)) = symbolName(s) + "?";

str symbolName(\iter-star(Symbol s)) = symbolName(s) + "*";

str symbolName(\iter-star-seps(Symbol s, _)) = symbolName(s) + "*";

str symbolName(\iter(Symbol s)) = symbolName(s) + "+";

str symbolName(\iter-seps(Symbol s, _)) = symbolName(s) + "+";

str symbolName(label(_, Symbol s)) = symbolName(s);

str symbolName(\start(Symbol s)) = symbolName(s);


Production findProd(type[&T<:Tree] tt, str class) = findSmallestProdHavingFields(tt, class, {});

Production findSmallestProdHavingFields(type[&T<:Tree] tt, str class, set[str] required) {
  int lastSize = 100000;
  list[Production] result = [];
  
  for (Symbol s <- tt.definitions, Production p <- tt.definitions[s].alternatives, p.def is label, p.def.name == class) {
    set[str] supported = { f | label(str f, Symbol _) <- p.symbols };
    if (required <= supported, size(supported) < lastSize) {
      result += [p];
      lastSize = size(supported);
    }  
  }
  
  return result[-1]; 
}


@doc{Synthesize a tree for a production given tree prototypes}
Tree prod2tree(Production p, map[Production, Tree] protos)
  = appl(p, symbols2args(p.symbols, protos[p].args))
  when p in protos;

// if there's no prototype, delegate to the synthsizing one.  
default Tree prod2tree(Production p, map[Production, Tree] protos)
  = prod2tree(p);

list[Tree] symbols2args(list[Symbol] syms, list[Tree] protos) 
  = [ symbol2tree(syms[i], protos[i]) | int i <- [0..size(syms)] ];

// labeled arguments always map to prototypes
Tree symbol2tree(label(str field, Symbol s), Tree _) = placeholder(s, field);

// but otherwise we reuse the existing tree.
default Tree symbol2tree(Symbol _, Tree proto)  = proto;
  

@doc{Synthesize a tree for a production without prototypes}
Tree prod2tree(Production p) = appl(p, symbols2args(p.symbols));
  
@doc{Synthesize tree arguments for a list of symbols w/o prototypes}
list[Tree] symbols2args(list[Symbol] syms)  
  // note how the current list of arguments is passed into symbol2tree to do layout normalization
  = ( [] | it + [symbol2tree(syms[i], i, it)] | int i <- [0..size(syms)] );
  
Tree symbol2tree(label(str field, Symbol s), int pos, list[Tree] prevs) 
  = placeholder(s, field);

Tree symbol2tree(lit(str x), int pos, list[Tree] prevs) 
  = appl(prod(lit(x), [], {}), [ char(i) | int i <- chars(x) ]);

Tree symbol2tree(s:layouts(_), int pos, list[Tree] prevs)  {
  if (pos > 0, isEmpty(prevs[pos - 1])) { // no layout needed
    return appl(prod(s, [], {}), []);
  }
  return appl(prod(s, [], {}), [ char(i) | int i <- chars(" ") ]);
}


bool isEmpty(appl(regular(_), [])) = true;

default bool isEmpty(Tree _) = false;


Tree addLoc(Tree t, Tree old) = (old has \loc) ? t[@\loc=old@\loc] : t;  
  
Tree setArg(t:appl(Production p, list[Tree] args), int i, Tree a)
  = addLoc(appl(p, args[0..i] + [a] + promoteHeadLayout(args[i+1..], a)), t);
  
Tree setArgs(Tree t, map[str, Tree] fields) 
  = ( t | setArg(it, getFieldIndex(t.prod, f), fields[f]) | str f <- fields );
  

list[Tree] promoteHeadLayout(list[Tree] args, Tree elt) {
  if (size(args) > 0, args[0].prod.def is layouts, "<args[0]>" == "", !isEmpty(elt)) { 
    return [appl(args[0].prod, [ char(i) | int i <- chars(" ") ]), *args[1..]];
  }
  if (isEmpty(elt)) { // remove it; it should have layout before
    return [appl(args[0].prod, [ ]), *args[1..]];
  }
  
  return args;
}  
  
@doc{Obtain a list of separator trees for a regular tree (possibly given prototypes)}
list[Tree] getSeparators(Tree lst, map[Production, Tree] protos = ()) {
  assert lst.prod is regular;
  
  s = lst.prod.def;
  int sepSize = 0;
  if (s is \iter-seps || s is \iter-star-seps) {
    sepSize = size(s.separators);
  }
  
  // if lst itself has separators, use them
  if (size(lst.args) > 1) {
    return sepSize > 0 ? lst.args[1..1+sepSize] : [];
  }
  
  // else look into prototypes
  if (lst.prod in protos) {
    return protos[lst.prod].args[1..1+sepSize];  
  }
  
  // else synthesize
  return symbols2args(s.separators); 
}
  
    
Tree insertList(Tree t, int pos, Tree x, list[Tree] seps) {
  assert t.prod is regular;
  int sepSize = size(seps);
    
  int idx = pos * (sepSize + 1);
  
  if (idx == 0, t.args == []) {
    return addLoc(appl(t.prod, [x]), t);
  }  
  
  if (idx == 0 || idx == 1 + sepSize, size(t.args) == 1) {
    if (idx == 0) {
      return addLoc(appl(t.prod, [x] + seps + t.args), t);
    }
    if (idx == 1 + sepSize) {
      return addLoc(appl(t.prod, t.args + seps + [x]), t);
    }
  }
  
  assert size(t.args) > 1;
  
  if (idx >= size(t.args)) {
    return addLoc(appl(t.prod, t.args + seps + [x]), t);
  }
  
  
  if (idx == 0) {
    return addLoc(appl(t.prod, [x] + seps + t.args), t);
  }
  
  return addLoc(appl(t.prod, t.args[0..idx]  + [x] + seps + t.args[idx..]), t);
}  
  
  
Tree removeList(Tree t, int pos, list[Tree] seps) {
  assert t.prod is regular;
  int sepSize = size(seps);

  int idx = pos * (sepSize + 1);
  
  // singleton
  if (idx == 0, size(t.args) == 1) {
    return addLoc(appl(t.prod, []), t);
  }
  
  
  // last one
  if (idx - sepSize == size(t.args) - 1) {
    return addLoc(appl(t.prod, t.args[0..-(1 + sepSize)]), t);
  }

  
  if (idx == 0) {
    return addLoc(appl(t.prod, t.args[idx+sepSize+1..]), t);
  }
  
  // default: also remove separators.
  return addLoc(appl(t.prod, t.args[0..idx] + t.args[idx+sepSize+1..]), t);  
}





