module lang::ecore::tests::MetaModel

import lang::ecore::Refs;


// All "meta-adts" need to have uid, might have src, and root models must have pkgURI.

data Machine(loc pkgURI = |http://www.example.org/myfsm|)
  = Machine(str name, list[State] states, Ref[State] initial = null(), Id uid = noId());
  
data State
  = State(str name, list[Trans] transitions, bool final = false, Id uid = noId())
  | State(Group group
     , str name = group.name
     , list[Trans] transitions = group.transitions
     , bool final = group.final
     , list[State] states = group.states
     , Id uid = group.uid
     , bool _inject = true) 
  ;

data Group
  = Group(str name, list[Trans] transitions, bool final = false, list[State] states = [], Id uid = noId())
  ;

data Trans
  = Trans(list[str] events, Ref[State] target, Id uid = noId())
  | Trans(Guarded guarded
     , list[str] events = guarded.events
     , Ref[State] target = guarded.target
     , Id uid = guarded.uid
     , bool _inject = true)
  ;
  
data Guarded
  = Guarded(list[str] events, Ref[State] target, str guard, Id uid = noId())
  ;  
