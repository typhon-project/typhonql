module lang::ecore::tests::TestLoad

import lang::ecore::Ecore;
import lang::ecore::IO;

import lang::ecore::diff::Diff;

import Node;
import IO;
import String;
import List;


private str myFSMecore = "\<?xml version=\"1.0\" encoding=\"UTF-8\"?\>
\<ecore:EPackage xmi:version=\"2.0\" xmlns:xmi=\"http://www.omg.org/XMI\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"
    xmlns:ecore=\"http://www.eclipse.org/emf/2002/Ecore\" name=\"myfsm\" nsURI=\"http://www.example.org/myfsm\" nsPrefix=\"myfsm\"\>
  \<eClassifiers xsi:type=\"ecore:EClass\" name=\"Machine\"\>
    \<eStructuralFeatures xsi:type=\"ecore:EReference\" name=\"states\" upperBound=\"-1\"
        eType=\"#//State\" containment=\"true\"/\>
    \<eStructuralFeatures xsi:type=\"ecore:EAttribute\" name=\"name\" eType=\"ecore:EDataType http://www.eclipse.org/emf/2002/Ecore#//EString\"/\>
    \<eStructuralFeatures xsi:type=\"ecore:EReference\" name=\"initial\" eType=\"#//State\"/\>
  \</eClassifiers\>
  \<eClassifiers xsi:type=\"ecore:EClass\" name=\"State\"\>
    \<eStructuralFeatures xsi:type=\"ecore:EReference\" name=\"transitions\" upperBound=\"-1\"
        eType=\"#//Trans\" containment=\"true\"/\>
    \<eStructuralFeatures xsi:type=\"ecore:EAttribute\" name=\"name\" lowerBound=\"1\" eType=\"ecore:EDataType http://www.eclipse.org/emf/2002/Ecore#//EString\"
        iD=\"true\"/\>
  \</eClassifiers\>
  \<eClassifiers xsi:type=\"ecore:EClass\" name=\"Trans\"\>
    \<eStructuralFeatures xsi:type=\"ecore:EReference\" name=\"target\" lowerBound=\"1\"
        eType=\"#//State\"/\>
    \<eStructuralFeatures xsi:type=\"ecore:EAttribute\" name=\"event\" lowerBound=\"1\" eType=\"ecore:EDataType http://www.eclipse.org/emf/2002/Ecore#//EString\"/\>
  \</eClassifiers\>
\</ecore:EPackage\>";

test bool testLoadMyFSMEcore() {
  uri = |project://rascal-ecore/src/lang/ecore/tests/MyFSM.ecore|;
  writeFile(uri, myFSMecore);
  return testLoadSaveIsEqual(uri);
}

bool testLoadSaveIsEqual(loc uri) {

  try {
    EPackage mm = load(#EPackage, uri);
  
    save(#EPackage, mm, uri[extension="saved"], |http://www.eclipse.org/emf/2002/Ecore|);

    EPackage mmSaved = load(#EPackage, uri[extension="saved"], uri);
    
    d = diff(#EPackage, mm, mmSaved);
    if (d.edits != []) {
      iprintln(d);
    }  
  
    return d.edits == [];
  }
  catch value v: {
    println("Exception for <uri>: <v>");
    return false;
  }
  
  
}

void testLoadSaveSamples() {
  ecores = |project://rascal-ecore/src/lang/ecore/samples|.ls;
  int success = ( 0 | it + (testLoadSaveIsEqual(e) ? 1 : 0) | loc e <- ecores );
  println("<size(ecores) - success> failed/error; <success> success");
}
