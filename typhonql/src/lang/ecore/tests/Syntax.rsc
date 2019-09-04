module lang::ecore::tests::Syntax

extend lang::std::Layout;
extend lang::std::Id;

import lang::ecore::Grammar2Ecore;
import lang::ecore::Ecore2HUTN;
import lang::ecore::Ecore;


start syntax Machine
  = @ref{initial:State:/states[name=$initial]} 
  Machine: "machine" Id name "init" Id initial State* states "end"
  ;
  
syntax State
  = State: "final"? final "state" Id name Trans* transitions "end"
  | Group: "group" Id name  "{" State* states "}"
  ;
  
  
syntax Trans
  = @ref{target:State:/states[name=$target]} Trans: "on" {Id ","}+ events "=\>" Id target
  | @ref{target:State:/states[name=$target]} Trans: "on" {Id ","}+ events "when" Str guard "=\>" Id target
  ;
  

lexical Str
  = [\"] ![\"]* [\"];

// for testing purposes
lexical Id
  = "\<" Id ":" "Id" "\>";


void writeMyFsmHUTNGrammar() {
  EPackage pkg =  grammar2ecore(#lang::ecore::tests::Syntax::Machine, "myfsm");
  writeHUTNModule("lang::ecore::tests::StmHUTN"
    , |project://rascal-ecore/src/lang/ecore/tests/StmHUTN.rsc|, pkg, "Machine");
}

 Machine example() = (Machine)
`machine Doors
'  init closed
'
'  state closed
'    on open =\> opened
'    on lock =\> locked
'  end
' 
'  state opened
'    on close =\> closed
'  end
'  
'  state locked
'    on unlock =\> closed
'  end
'end`;
 
 Machine example2() = (Machine)
`machine Doors
'  init closed
'
'  state closed
'    on open =\> opened
'  end
' 
'  state opened
'    on close =\> closed
'  end
'  
'  state locked
'  end
'end`;