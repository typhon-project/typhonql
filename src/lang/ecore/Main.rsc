module lang::ecore::Main

import lang::ecore::Ecore;
import lang::ecore::IO;
import IO;


void main() {
  EPackage mm = load(#EPackage, |file:///Users/tvdstorm/CWI/typhonml/it.univaq.disim.typhonml/model/typhonml.ecore|);
  iprintln(mm);
}
