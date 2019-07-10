module lang::ecore::tests::TestRefs

import lang::ecore::Refs;

import lang::ecore::tests::MetaModel;

import IO;

bool check(value actual, value expected) {
  if (actual != expected) {
    println("FAIL");
    println("GOT: <actual>");
    println("EXPECTED: <expected>");
  }
  return actual == expected;
}

Machine theDoors(Realm r = newRealm()) {
  m = r.new(#Machine, Machine("doors", []));
  s1 = r.new(#State, State("closed", []));
  s2 = r.new(#State, State("opened", []));
  t1 = r.new(#Trans, Trans(["open"], referTo(#State, s2)));
  t2 = r.new(#Trans, Trans(["close"], referTo(#State, s1)));
  s1.transitions = [t1];
  s2.transitions = [t2];
  m.states = [s1, s2];
  return m;
} 


test bool testRefIntegrityDoors() 
  = check(checkReferentialIntegrity(theDoors()), <{}, []>); 

test bool testRefIntegrityEmpty() 
  = check(checkReferentialIntegrity(theDoors()[states=[]]), <{}, []>); 

test bool testRefIntegrityDoorsDangling() {
  m = theDoors();
  m.states = [m.states[1]]; // remove s1 to create dangling ref to it in s2
  return check(checkReferentialIntegrity(m), <{ref(id(1))}, []>); 
}

test bool testRefIntegrityDoorsDuplicateIds() {
  m = theDoors();
  m.states[0].transitions = []; // void the transitions to get only duplicates for states
  m.states[1].transitions = []; 
  m.states = [m.states[0], m.states[0]]; // copy to get two elements with same identity
  return check(checkReferentialIntegrity(m), 
     <{}, [<id(1),State("closed",[],uid=id(1))>,<id(1),State("closed",[],uid=id(1))>]>); 
}

test bool testLookupRef() {
  m = theDoors();
  return check(lookup(m, #State, m.states[1].transitions[0].target), m.states[0]);
}

test bool testLookupRefOverInjections() {
  Realm r = newRealm();
  Guarded g = r.new(#Guarded, Guarded(["opened"], null(), "exp"));
  Trans t = Trans(g); 
  // referring to Trans, looking up Guarded, produces Guarded.
  return check(lookup(t, #Guarded, referTo(#Trans, t)), g);   
}

test bool testGetClassOverInjections() {
  Realm r = newRealm();
  Guarded g = r.new(#Guarded, Guarded(["opened"], null(), "exp"));
  Trans t = Trans(g);
  return check(getClass(t), "Guarded");   
}

test bool testLookupNull() {
  m = theDoors();
  try { 
    lookup(m, #State, m.initial);
    return false;
  }  
  catch _:
    return true;
}

