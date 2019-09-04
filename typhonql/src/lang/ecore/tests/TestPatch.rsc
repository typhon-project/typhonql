module lang::ecore::tests::TestPatch

extend lang::ecore::tests::Syntax; // bug in reifier.
import lang::ecore::tests::MetaModel;
import lang::ecore::tests::Trafos;

import lang::ecore::text::Tree2Model;
import lang::ecore::text::PatchTree;
import lang::ecore::text::PTDiff;
import lang::ecore::diff::Diff;
import lang::ecore::Refs;

import ParseTree;
import IO;
import String;

/*
 * This module (implicitly) tests the following operations
 * - tree2model
 * - diff
 * - patchTree
 * - ptDiff
 */


str tester(str src, str key, lang::ecore::tests::MetaModel::Machine(lang::ecore::tests::MetaModel::Machine) trafo) {
  //gram = addPlaceholderProds(#lang::ecore::tests::Syntax::Machine);
  //type[lang::ecore::tests::Syntax::Machine] gram = #lang::ecore::tests::Syntax::Machine;
  loc org = |project://rascal-ecore/src/lang/ecore/tests/<key>.old|;
  writeFile(org, src);
  lang::ecore::tests::Syntax::Machine pt = parse(#start[Machine], src, org).top;
  <m, orgs> = tree2modelWithOrigins(#lang::ecore::tests::MetaModel::Machine, pt);
  
  //println("## ORGS");
  //for (Id x <- orgs) {
  //  println("<x>: <orgs[x]>");
  //}
  
  m2 = trafo(m);
  
  //println("## MODEL");
  //iprintln(m2);
  
  Patch patch = diff(#lang::ecore::tests::MetaModel::Machine, m, m2);
  
  //println("## PATCH");
  //iprintln(patch);
  
  // and here it needs to be the non-start reified type...
  pt2 = patchTree(#lang::ecore::tests::Syntax::Machine, pt, patch, orgs, Tree(type[&U<:Tree] tt, str src) {
    return parse(tt, src);
  });
  
  newSrc = "<pt2>"; 
  writeFile(|project://rascal-ecore/src/lang/ecore/tests/<key>.new|, newSrc);
  return newSrc;
}

/*
 * Patch to text 
 */
 
bool testDiff(loc old, loc new) {
  try {
      pt1 = parse(#start[Machine], old);
      pt2 = parse(#start[Machine], new);
      d = ptDiff(pt1, pt2);
      iprintln(d);
      src1 = "<pt1>";
      src2 = patch(src1, new, d);
      if (src2 != "<pt2>") {
        println("Patch fail:");
        println("NEW: <new>");
        println("EXP: <pt2>");
        println("GOT: <src2>");
        return false;
      }
      return true;
  }
  catch ParseError(loc l): {
    println("Exception for <old>: <l>");
    return false;
  }
} 
 
void testPTDiffAndPatch() {
  olds = [ l | loc l <- |project://rascal-ecore/src/lang/ecore/tests/|.ls, l.extension == "old" ];
  int fails = 0;
  int errs = 0;
  for (loc old <- olds) {
    loc new = old[extension="new"];
    if (!testDiff(old, new)) {
      fails += 1;
    } 
  } 
  println("<fails> failed; <errs> exceptions; <size(olds) - fails - errs> success");
}


/*
 * Creation
 */
 
str createMachineResult() {
  m = createFromScatch();
  pt2 = model2tree(#lang::ecore::tests::Syntax::Machine, #lang::ecore::tests::MetaModel::Machine, m, Tree(type[&U<:Tree] tt, str src) {
    return parse(tt, src);
  });
  return "<pt2>";
}

test bool testCreateMachine() 
  = createMachineResult() 
  == 
  "machine Doors init closed state closed on open =\> opened end state opened on close =\> closed end end";


str createMachineWithProtoLayoutResult() {
  m = createFromScatch();
  protos = layoutPrototypes(example());
  pt2 = model2tree(#lang::ecore::tests::Syntax::Machine, #lang::ecore::tests::MetaModel::Machine, m, Tree(type[&U<:Tree] tt, str src) {
    return parse(tt, src);
  }, protos = protos);
  return "<pt2>";
}

test bool testCreateMachineWithProtoLayout() 
  = createMachineWithProtoLayoutResult() 
  == 
  "machine Doors
  '  init closed
  '
  '  state closed
  '    on open =\> opened
  '  end
  ' 
  '  state opened
  '    on close =\> closed
  '  end
  'end";


/*
 * Insertion (plus creation)
 */

str addStateToEmptyResult() = tester("machine Doors
  									'init \<initial:Id\>
  									'end", "stateToEmpty", appendState);

test bool testAddStateToEmpty() 
  = addStateToEmptyResult() == 
  "machine Doors
  'init \<initial:Id\>
  'state NewState end
  'end";

str addStateToSingletonResult() = tester("machine Doors
  										'init closed
  										'state closed end
  										'end", "stateToSingleton", appendState);

test bool testAddStateToSingleton() 
  = addStateToSingletonResult()
  ==
  "machine Doors
  'init closed
  'state closed end state NewState end
  'end";
  
str addStateToManyResult() = tester("machine Doors
  								   'init closed
  								   'state closed end
  								   'state opened end
                                    'end", "stateToMany", appendState);

test bool testAddStateToMany() 
  = addStateToManyResult()
  ==
  "machine Doors
  'init closed
  'state closed end
  'state opened end
  'state NewState end
  'end";
  
  
str prependStateToSingletonResult() = tester("machine Doors
									        'init closed
									        'state closed end
									        'end", "prependToSingleton", prependState);
									        
test bool testPrependStateToSingleton()
  = prependStateToSingletonResult()
  ==
  "machine Doors
  'init closed
  'state NewState end state closed end
  'end";
  
str prependStateToManyResult() = tester("machine Doors
							           'init closed
							           'state closed end
							           'state opened end
							           'end", "prependToMany", prependState);
									        
test bool testPrependStateToMany()
  = prependStateToManyResult()
  ==
  "machine Doors
  'init closed
  'state NewState end
  'state closed end
  'state opened end
  'end";

str prependStateToManyWithProtoLayoutResult() = tester("machine Doors
											          'init closed
											          'state closed
											          'end
											          'state opened
											          'end
											          'end", "prependToMany", prependState);
									        
test bool testPrependStateToManyWithProtoLayout()
  = prependStateToManyWithProtoLayoutResult()
  ==
  "machine Doors
  'init closed
  'state NewState
  'end
  'state closed
  'end
  'state opened
  'end
  'end";

str prependEventToSingletonResult() = tester("machine Doors
                                            'init closed
                                            'state closed
                                            '  on bar =\> closed
                                            'end
                                            'end", "prependEventSingleton", addEvent(0));
  
test bool testPrependEventToSingletonResult()
  = prependEventToSingletonResult()
  == 
  "machine Doors
  'init closed
  'state closed
  '  on newEvent , bar =\> closed
  'end
  'end";
  
str appendEventToSingletonResult() = tester("machine Doors
                                            'init closed
                                            'state closed
                                            '  on bar =\> closed
                                            'end
                                            'end", "appendEventSingleton", addEvent(1));
  
test bool testAppendEventToSingletonResult()
  = appendEventToSingletonResult()
  == 
  "machine Doors
  'init closed
  'state closed
  '  on bar , newEvent =\> closed
  'end
  'end";  
  
  
  
str appendEventToManyResult() = tester("machine Doors
                                       'init closed
                                       'state closed
                                       '  on bar, foo =\> closed
                                       'end
                                       'end", "appendEventMany", addEvent(2));
  
test bool testAppendEventToMany()
  = appendEventToManyResult()
  == 
  "machine Doors
  'init closed
  'state closed
  '  on bar, foo, newEvent =\> closed
  'end
  'end";   

str insertEventToManyResult() = tester("machine Doors
                                            'init closed
                                            'state closed
                                            '  on bar, foo =\> closed
                                            'end
                                            'end", "insertEventMany", addEvent(1));
  
test bool testInsertEventToMany()
  = insertEventToManyResult()
  == 
  "machine Doors
  'init closed
  'state closed
  '  on bar, newEvent, foo =\> closed
  'end
  'end";
  
  
  
/*
 * Removal from lists
 */
 

str removeSingletonResult() = tester("machine Doors
 									'init closed
 									'state closed end
 									'end", "removeSingleton", removeStateAt(0));

test bool testRemoveSingleton()
  = removeSingletonResult()
  ==
  "machine Doors
  'init \<initial:Id\>
  'end";

str removeFromFrontResult() = tester("machine Doors
 									'init closed
 									'state closed end
 									'state opened end
 									'end", "removeFront", removeStateAt(0));

test bool testRemoveFromFront()
  = removeFromFrontResult()
  == 
  "machine Doors
  'init \<initial:Id\>
  'state opened end
  'end";
  

str removeFromEndResult() = tester("machine Doors
 								   'init closed
 								   'state closed end
 								   'state opened end
 								   'end", "removeEnd", removeStateAt(1));

test bool testRemoveFromEnd()
  = removeFromEndResult()
  ==
  "machine Doors
  'init closed
  'state closed end
  'end";
  

str removeFromMidResult() = tester("machine Doors
 								   'init closed
 								   'state closed end
 								   'state removed end
 								   'state opened end
 								   'end", "removeMid", removeStateAt(1));

test bool testRemoveFromMid()
  = removeFromMidResult()
  ==
  "machine Doors
  'init closed
  'state closed end
  'state opened end
  'end";

str removeAllResult() = tester("machine Doors
 								   'init closed
 								   'state closed end
 								   'state removed end
 								   'state opened end
 								   'end", "removeAll", removeStates([0,1,2]));

test bool testRemoveAll()
  = removeAllResult()
  ==
  "machine Doors
  'init \<initial:Id\>
  'end";
  
str removeEventAtEndFromTwoResult() = tester("machine Doors
                                            'init closed
                                            'state closed
                                            '  on bar, foo =\> closed
                                            'end
                                            'end", "removeEventAtEnd", removeEvent(1));
  
test bool testRemoveEventAtEndFromTwoResult()
  = removeEventAtEndFromTwoResult()
  == 
  "machine Doors
  'init closed
  'state closed
  '  on bar =\> closed
  'end
  'end";

str removeEventAtStartFromTwoResult() = tester("machine Doors
                                            'init closed
                                            'state closed
                                            '  on bar, foo =\> closed
                                            'end
                                            'end", "removeEventAtStart", removeEvent(0));
  
test bool testRemoveEventAtStartFromTwoResult()
  = removeEventAtStartFromTwoResult()
  == 
  "machine Doors
  'init closed
  'state closed
  '  on foo =\> closed
  'end
  'end";

str removeEventInTheMiddleFromManyResult() = tester("machine Doors
		                                            'init closed
		                                            'state closed
		                                            '  on bar, removed, foo =\> closed
		                                            'end
		                                            'end", "removeEventMid", removeEvent(1));
  
test bool testRemoveEventInTheMiddleFromManyResult()
  = removeEventInTheMiddleFromManyResult()
  == 
  "machine Doors
  'init closed
  'state closed
  '  on bar, foo =\> closed
  'end
  'end";
  
    
  
/* 
 * Permutations
 */

str swapTwoStatesResult() = tester("machine Doors
 								   'init closed
 								   'state closed end
 								   'state opened end
 								   'end", "swapTwo", swapState(0, 1));

test bool testSwapTwoStates()
  = swapTwoStatesResult()
  ==
  "machine Doors
  'init closed
  'state opened end
  'state closed end
  'end";


str swapBeginEndStatesResult() = tester("machine Doors
 								   'init closed
 								   'state closed end
 								   'state A end
 								   'state B end
 								   'state C end
 								   'state opened end
 								   'end", "swapBeginEnd", swapState(0, 4));

test bool testSwapBeginEndStates()
  = swapBeginEndStatesResult()
  ==
  "machine Doors
  'init closed
  'state opened end
  'state A end
  'state B end
  'state C end
  'state closed end
  'end";

str reverseAllStatesResult() = tester("machine Doors
 								   'init closed
 								   'state closed end
 								   'state A end
 								   'state B end
 								   'state C end
 								   'state opened end
 								   'end", "reverseStates", reverseStates);

test bool testReverseAllStates()
  = reverseAllStatesResult()
  ==
  "machine Doors
  'init closed
  'state opened end
  'state C end
  'state B end
  'state A end
  'state closed end
  'end";


/*
 * Properties
 */
 

str setMachineNameResult() = tester("machine Doors
             					   'init closed
             					   'end", "setName", setMachineName("Foo"));
 
test bool testSetMachineName()
  = setMachineNameResult()
  ==
  "machine Foo
  'init \<initial:Id\>
  'end"; 

str setStateNameWithRefResult() = tester("machine Doors
 										'init closed
 										'state closed end
 										'end", "setNameWithRef", setStateName(0, "CLOSED"));
 										
test bool testSetStateNameWithRef()
  = setStateNameWithRefResult()
  == 
  "machine Doors
  'init CLOSED
  'state CLOSED end
  'end";
  
  
str makeStateFinalResult() = tester("machine Doors
								   'init closed
								   'state closed end
								   'end", "makeStateFinal", makeStateFinal("closed", true));
								   
test bool testMakeStateFinal()
  = makeStateFinalResult()
  == 
  "machine Doors
  'init closed
  'final state closed end
  'end";  
  
str makeStateNotFinalResult() = tester("machine Doors
								      'init closed
								      'final state closed end
								      'end", "makeStateNotFinal", makeStateFinal("closed", false));
								   
test bool testMakeStateNotFinal()
  = makeStateNotFinalResult()
  == 
  "machine Doors
  'init closed
  'state closed end
  'end";  
  
/*
 * Cross references.
 */
  
  
str setInitialToNullResult() = tester("machine Doors
                                      'init closed
                                      'state closed end
                                      'end", "setNull", setInitial("nonExisting"));
                                      
test bool testSetInitialToNullGivesNullTree()
  = setInitialToNullResult()
  ==
  "machine Doors
  'init \<initial:Id\>
  'state closed end
  'end";
  
  
str setInitialToExistingStateResult() = tester("machine Doors
                                               'init closed
                                               'state closed end
                                               'state opened end
                                               'end", "setRef", setInitial("opened"));
                                               
test bool testSetInitialToExistingState()
  = setInitialToExistingStateResult()
  ==
  "machine Doors
  'init opened
  'state closed end
  'state opened end
  'end";
  
 /* 
  * Abritrary trafos
  */
  

str arbitraryTrafo1Result() = tester("machine Doors
                                    'init closed
                                    'state closed end
                                    'state opened end
                                    'state locked end
                                    'end", "arbitraryTrafo1", arbitraryTrafo1);

 
 test bool testArbitraryTrafo1()
   = arbitraryTrafo1Result()
   ==
   "machine Doors_
   'init NewState_3
   'state BLA on bar =\> NewState_3 end
   'state closed end
   'state locked end
   'state NewState_3 end
   'end";
   
   
   
   
   
   
   
   
 
  
