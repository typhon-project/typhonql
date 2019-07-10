module lang::ecore::tests::StmHUTN

extend lang::ecore::hutn::Base;
import util::IDE;
import ParseTree;


syntax Group_Field =
  @inject State_Field 
  |  states: "states"  ":"  "["  State*  "]" 
  ;

syntax Group =
  @Foldable Group: "Group"  Name name  "{"  Group_Field* fields  "}" 
  ;

syntax Trans =
  @Foldable Trans: "Trans"  "{"  Trans_Field* fields  "}" 
  ;

syntax State_Field =
   transitions: "transitions"  ":"  "["  Trans*  "]" 
  |  final: "final"  ":"  Bool 
  |  name: "name"  ":"  Str 
  ;

syntax Trans_Field =
   guard: "guard"  ":"  Str 
  |  target: "target"  ":"  Ref[State] 
  |  events: "events"  ":"  "["  Str*  "]" 
  ;

syntax Machine_Field =
   states: "states"  ":"  "["  State*  "]" 
  |  initial: "initial"  ":"  Ref[State] 
  |  name: "name"  ":"  Str 
  ;

start syntax Machine =
  @Foldable Machine: "Machine"  Name name  "{"  Machine_Field* fields  "}" 
  ;

syntax State =
  @inject Group 
  | @Foldable State: "State"  Name name  "{"  State_Field* fields  "}" 
  ;


start[Machine] parseMyfsm(str src, loc l)
  = parse(#start[Machine], src, l);

void main() {
  registerLanguage("myfsm", "myfsm_hutn", start[Machine](str src, loc org) {
    return parseMyfsm(src, org);
  });
}