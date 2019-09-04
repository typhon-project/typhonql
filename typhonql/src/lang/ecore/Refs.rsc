module lang::ecore::Refs

import Type;
import Node;
import IO;
import List;


@doc{Realms capture object spaces and are used to create model elements at the Rascal side}
alias Realm = tuple[&T(type[&T<:node], &T) new];

@doc{Object identities are represented by Id. When created using a Realm
consecutive integers are used to create unique ids. Some operations use
source locations capturing paths in a model.}
data Id 
  = id(int n)
  | id(loc uri);

@doc{Cross references are represented by the Ref data type. 
The type parameter is used to allow meta model ADTs document
the type of the reference target.}
data Ref[&T]
  = ref(Id uid)
  | null()
  ; 

alias RefErr = tuple[set[Ref[value]] danglingRefs, lrel[Id, node] duplicateIds];

@doc{Check a model for duplicate ids and dangling references}
RefErr checkReferentialIntegrity(node model)
  = <danglingRefs(model), duplicateIds(model)>;

@doc{Find the set of Refs for which no target exists in the model}
set[Ref[value]] danglingRefs(node model) 
  = { r | /Ref[void] r:ref(_) := model, !any(/node x := model, isObj(x), getId(x) == r.uid) };

@doc{Find the list of Id-element pairs which share Id with another.
NB: we use list, because the nodes maybe Rascal-equal.}
lrel[Id, node] duplicateIds(node model) {
  // NB: elements on the containment hierarchy
  // in collections should always be unique (as per Ecore).
  // IOW: no sharing on the containment hierarchy is allowed anywhere.
  r = [ <getId(elt), elt> | /node elt := model, isObj(elt) ];
  return [ <x, elt> | <Id x, node elt> <- r, size(r[x]) > 1 ]; 
}


  
@doc{Lookup a reference `r` of type `typ` starting at `root`.}
// TODO: lookup should return Maybe.... What if r is null()?
&T<:node lookup(node root, type[&T<:node] typ, Ref[&T] r) = aNode
  when /&T<:node aNode := root, getId(aNode) == r.uid;

default &T<:node lookup(node root, type[&T<:node] typ, Ref[&T] r) {
  throw "Could not find ref <r> to type <typ> in: \n<root>";
}

@doc{Create a reference of type `typ` to value `t`}    
Ref[&T] referTo(type[&T<:node] typ, &T t) = ref(getId(t));

@doc{Obtain the identity of a model element. Note that this function
looks over injections}
Id getId(&T<:node t) {
  kws = getKeywordParameters(t);;
  if ("uid" in kws, Id x := kws["uid"]) {
    return x;
  }
  return getId(getChildren(t)[0]);  // injection
} 
  
bool isInjection(node t) = !(t has uid);

@doc{Find the "deepest" model element below `t` that is not an injection} 
node uninject(node t) {
  if (t has uid) { // assumes uid is never *set* on injections
    return t;
  }
  return uninject(typeCast(#node, getChildren(t)[0])); 
}  

@doc{Determine if a node value has an Id. NB: injections are not
assumed to have an id (even though the uid keyword param is in the data type}  
bool hasId(node t) {
  if (isRef(t)) {
    return false;
  }
  if (t has uid) {
    return true;
  }
  if (arity(t) == 0) {
    return false;
  }
  return hasId(getChildren(t)[0]); // injection
}

bool isRef(node n) = (Ref[void] _ := n);

bool isId(node n) = (Id _ := n);

bool isObj(node n) = !isRef(n) && !isId(n) && hasId(n);

// this currently does not care about injections...
&T<:node setId(&T<:node x, Id id) = 
  setKeywordParameters(x, getKeywordParameters(x) + ("uid": id));

&T<:node become(&T<:node x, Id id) = new
  when &T new := setId(x, id); 


@doc{Create a new object space as a factory for model elements}
Realm newRealm() {
  int idCount = -1; 

  Id newId() {
    idCount += 1;
    return id(idCount);
  }

  &T new(type[&T<:node] t, &T x, Id id = newId()) {
    return setId(x, id); 
  }

  return <new>;
}

Id noId() {
  throw "You should have used `new` on a Realm to make things with ids.";
}

loc noLoc() {
  throw "No location has been set";
}

str getClass(node n) = getName(uninject(n));

Symbol getType(node n) = typeOf(uninject(n));


@doc{Referential equality predicate: nodes are also equal if their identities are equal} 
bool refEq(node n, ref(Id x)) = getId(n) == x when !isRef(n);

bool refEq(ref(Id x), node n) = getId(n) == x when !isRef(n);

bool refEq(node n1, node n2) = getId(n1) == getId(n2) 
  when !isRef(n1), !isRef(n2);
   
bool refEq(list[value] vs1, list[value] vs2)
  = size(vs1) == size(vs2)  
  && ( true | it && refEq(vs1[i], vs2[i]) | i <- [0..size(vs1)] ); 

// also covers ref/null cases on both sides
default bool refEq(value v1, value v2) = v1 == v2;

