module lang::ecore::tests::Trafos

import lang::ecore::tests::MetaModel;
import lang::ecore::Refs;
import List;




Machine appendState(Machine m, str name = "NewState") {
  r = newRealm();
  s = r.new(#State, State(name, []));
  m.states += [s];
  return m;
}

Machine createFromScatch() {
  r = newRealm();
  s1 = r.new(#State, State("closed", []));
  s2 = r.new(#State, State("opened", []));
  s1.transitions += [r.new(#Trans, Trans(["open"], referTo(#State, s2)))];
  s2.transitions += [r.new(#Trans, Trans(["close"], referTo(#State, s1)))];
  m = r.new(#Machine, Machine("Doors", [s1, s2]));
  m.initial = referTo(#State, s1);
  return m;
}

Machine prependState(Machine m, str name = "NewState") {
  r = newRealm();
  s = r.new(#State, State(name, []));
  m.states = [s] + m.states;
  return m;
}

Machine(Machine) removeStateAt(int idx) {
  return Machine(Machine m) {
    m.states = delete(m.states, idx);
    return m;
  };
}


Machine(Machine) addEvent(int idx) {
  return Machine(Machine m) {
    m.states[0].transitions[0].events = insertAt(m.states[0].transitions[0].events, idx, "newEvent");  
    return m;
  };
}

Machine(Machine) removeEvent(int idx) {
  return Machine(Machine m) {
    m.states[0].transitions[0].events = delete(m.states[0].transitions[0].events, idx);  
    return m;
  };
}


Machine(Machine) removeStates(list[int] idxs) {
  return Machine(Machine m) {
    newStates = [];
    for (int idx <- [0..size(m.states)], idx notin idxs) {
      newStates += [m.states[idx]];
    }
    m.states = newStates;
    return m;
  };
}

Machine(Machine) swapState(int i, int j) {
  return Machine(Machine m) {
    tmp = m.states[i];
    m.states[i] = m.states[j];
    m.states[j] = tmp;
    return m;
  };
}

Machine reverseStates(Machine m) {
  m.states = reverse(m.states);
  return m;
}

Machine(Machine) setMachineName(str name) {
  return Machine(Machine m) {
    m.name = name;
    return m;
  };
}

Machine(Machine) setStateName(int idx, str name) {
  return Machine(Machine m) {
    s = m.states[idx];
    s.name = name;
    m.states[idx] = s;
    return m;
  };
}

Machine(Machine) setInitial(str name) {
  return Machine(Machine m) {
    if (State s <- m.states, s.name == name) {
      m.initial = referTo(#State, s);
    }
    else {
      m.initial = null();
    }
    return m;
  };
}

Machine(Machine) makeStateFinal(str name, bool b) {
  return Machine(Machine m) {
    if (int i <- [0..size(m.states)], m.states[i].name == name) {
      m.states[i].final = b;
    }
    return m;
  };
}

Machine arbitraryTrafo1(Machine m) {
  r = newRealm();
  newState = r.new(#State, State("NewState_<size(m.states)>", []));
  m.states = [m.states[0]] + [m.states[2]];
  bla = r.new(#State, State("BLA", []));
  tr = r.new(#Trans, Trans(["bar"], referTo(#State, newState)));
  bla.transitions += [tr];
  m.states += [newState];
  m.states = [bla] + m.states;
  m.initial = referTo(#State, newState);
  m.name = m.name + "_";
  return m;
}
