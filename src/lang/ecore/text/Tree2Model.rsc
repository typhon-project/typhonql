module lang::ecore::text::Tree2Model

import lang::ecore::text::Grammar2Ecore;
import lang::ecore::text::Paths;
import lang::ecore::Refs;

import ParseTree;
import Type;
import List;
import IO;
import String;
import Node;
import Map;

/*
Assumptions
- all prods from grammar correspond to class with identity
- refs are always primitives (i.e. lexicals)
- ref paths are only along the containment hierarchy.
- all regulars are mapped to lists (?)

TODO
- use meta model (EPackage, not type[&M<:node]...
*/


alias Fix = void(node, lrel[str field, str path]);
alias Track = void(Id, loc);

// the cross references for an object identified by Id
alias FixUps = map[Id, lrel[str field, str path]];


&M<:node tree2model(type[&M<:node] meta, Tree t, loc uri = t@\loc) 
  = tree2modelWithOrigins(meta, t, uri = uri)[0];

// origins map object ids to source locations
// (all trees with grammar productions should be in here)
alias Org = map[Id id, loc src];

tuple[&M<:node, Org] tree2modelWithOrigins(type[&M<:node] meta, Tree t, loc uri = t@\loc)  {
  t = (t has top ? t.top : t);
  
  FixUps fixUps = ();
  Org origins = ();
  
  void track(Id x, loc l) {
    origins[x] = l;
  }
  
  void fix(node obj, lrel[str field, str path] fixes) {
    fixUps[getId(obj)] = fixes;
  }
  
  model = tree2model(meta, newRealm(), t, fix, uri, "/", track);
  model = fixUp(meta, model, fixUps);  
  
  return <typeCast(meta, model), origins>;
}

value tree2model(type[&M<:node] meta, Realm r, Tree t, Fix fix, loc uri, str xmi, Track track) {
  p = t.prod;
  
  if (p.def is lex) {
    return "<t>"; // for now, lexical map to just strings
  }
  
  largs = labeledAstArgs(t, p);

  if (p is regular) {
    // optional literals are special cased to booleans
    if (opt(lit(str _)) := p.def) {
      return t.args != [];
    }
    
    // otherwise they end up as lists in the model
    return [ tree2model(meta, r, largs[i][1], fix, uri, xmi + ".<i>", track) | int i <- [0..size(largs)] ];
  }

  // for an ordinary production we create an environment mapping field names to values
  // based on the labeled argument trees of the current tree.
  lrel[str, value] env = [ <fld, tree2model(meta, r, a, fix, uri, xmi + "/@<fld>", track)> 
     | int i <- [0..size(largs)], <str fld, Tree a> := largs[i] ];


  lrel[str, str] fixes = [];
  
  // if some of the values in the environments should be interpreted
  // as cross references, we move them to `fixes` here.
  env = for (<str fld, value v> <- env) {
    if (<fld, _, str path> <- prodRefs(p)) {
      // NB: assumption is refs are always on the spine
      // so it is safe to use env here, even though we're building it.
      fixes += [<fld, substBindings(path, env)>];
      
      // cross refs are resolved later, so for now assign to null
      append <fld, null()>;
    }
    else {
      append <fld, v>;
    }      
  }  

  // start constructing the ADT value...  
  adtName = p.def is label ? p.def.symbol.name : p.def.name;
  tt = type(adt(adtName, []), meta.definitions);
  
  args = ();  
  kws = (); 
  
  for (<str fld, value v> <- env) {
    int idx = getFieldIndex(meta, adt(adtName, []), p.def.name, fld); 
    if (idx != -1) {
      args[idx] = v;
    }
    else { // assume it's a keyword param.
      kws[fld] = v;
    }
  }
  
  // if a production has @id{x} the value of field x is used
  // as a globally unique identifier of the object
  if (str x <- prodIds(p), <x, str v> <- env) {
  	uri.fragment = v;
  }
  else { // else it's the XMI path
  	uri.fragment = xmi;
  }
  
  // communicate the origin to tree2modelWithOrigins
  Id myId = id(uri.top);
  if (t@\loc?) {
    track(myId, t@\loc);
  }
  else {
    println("WARNING: no loc for <t>");
  }

  // build the object with the explicitly constructed Id  
  // note that `args` is a map, not a list
  obj = r.new(tt, make(tt, p.def.name, [ args[i] | int i <- [0..size(args)] ], kws), id = myId);
  
  // and schedule fixes for all cross references.
  fix(obj, fixes);
  
  return obj;
}

@doc{Given a model, and a set of fixups resolve the cross references}
&M<:node fixUp(type[&M<:node] meta, &M model, FixUps fixes) {
  // The stuff with typeOf etc is truly horrible here.
  // It works now, but I'd like it to be simpler.
  
  &T<:node fixup(type[&T<:node] t, &T<:node obj) {
    c = getName(obj);
    kws = getKeywordParameters(obj);
    alts = meta.definitions[t.symbol].alternatives;

    for (<str fld, str path> <- fixes[getId(obj)]) {
      kids = getChildren(obj);
      target = deref(meta, model, path);
      
      // if the cross ref is an ordinary parameter...
      if (cons(label(c, _), ps:[*_, p:label(fld, rt:adt("Ref", _)), *_], _, _) <- alts) {
        int i = indexOf(ps, p);
        obj = make(t, c, kids[0..i] + [target is null ? target : referTo(type(rt, meta.definitions), target)] + kids[i+1..], kws);
      }
      // or if it is a keyword parameter...
      else if (cons(label(c, _), _, [*_, p:label(fld, rt:adt("Ref", _)), *_], _) <- alts) {
        obj = setKeywordParameters(obj, kws + (fld: target is null ? target : referTo(type(rt, meta.definitions), target))); 
      }
      else {
        throw "Cannot find constructor for fixing <obj>.<fld> to <path>";
      }
    }

    return typeCast(t, obj);
  }
  
  // for each node in the model that is an object, fix its cross references
  return typeCast(meta, visit(model) {
    case node n => fixup(type(typeOf(n), meta.definitions), n) when isObj(n)
  });
}


@doc{Dereference the path `path`, starting at `root`}
node deref(type[&M<:node] meta, &M root, str path) {
  try {
    return deref(meta, root, parsePath(path));
  }
  catch InvalidArgument(_, _): {
    return null();
  }
} 


lrel[str, Tree] labeledAstArgs(Tree t, Production p) 
  =  [ <(p has symbols && p.symbols[i] is label) ? p.symbols[i].name : "", t.args[i]> 
  // NB: we skip layout immediately.
       | int i <- [0,2..size(t.args)], isAST(t.args[i]) ];

str substBindings(str path, lrel[str, value] env) 
  = ( path | replaceAll(it, "$<x>", "<v>") | <str x, value v> <- env );


bool isAST(Tree t) = t has prod && !(t.prod.def is lit || t.prod.def is cilit);

