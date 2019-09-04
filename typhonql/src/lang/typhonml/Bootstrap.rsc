module lang::typhonml::Bootstrap

import lang::ecore::Ecore;
import lang::ecore::IO;
import lang::ecore::Ecore2ADT;


// change this to location of the TyphonML metamodel before calling bootstrap
loc TYPHONML_ECORE = |file:///Users/tvdstorm/CWI/typhonml/it.univaq.disim.typhonml/model/typhonml.ecore|;

@doc{Run this after the ECore meta model of TyphonML changes}
void bootstrap() {
  EPackage pkg = load(#EPackage, TYPHONML_ECORE); 
  writeEcoreADTModule("lang::typhonml::TyphonML", |project://typhonql/src/lang/typhonml/TyphonML.rsc|, pkg);
}

