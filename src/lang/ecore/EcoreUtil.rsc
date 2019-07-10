module lang::ecore::EcoreUtil

import lang::ecore::Ecore;
import lang::ecore::Refs;

EPackage flattenInheritance(Realm realm, EPackage mm) {
   EClass flattenClass(EClass t) {
     // TODO: instantiate the generic super types.
     supers = [ flattenClass(lookup(mm, #EClass, sup)) | sup <- t.eSuperTypes ]; 
     t.eStructuralFeatures  
       = [ EStructuralFeature(realm.new(#EAttribute, f)) | s <- supers, EStructuralFeature(EAttribute f) <- s.eStructuralFeatures ]
       + [ EStructuralFeature(realm.new(#EReference, f)) | s <- supers, EStructuralFeature(EReference f) <- s.eStructuralFeatures ]
       + t.eStructuralFeatures; 
    return t;
  }
 
  EClassifier flatten(EClassifier(EClass c)) = EClassifier(flattenClass(c));
  default EClassifier flatten(EClassifier c) = c; 

  mm.eClassifiers = [ flatten(c) | EClassifier c <- mm.eClassifiers ];
  return mm;
}

list[EClass] directSubclassesOf(EClass class, EPackage pkg) 
  = [ sub | EClassifier(EClass sub) <- pkg.eClassifiers, sup <- sub.eSuperTypes, lookup(pkg, #EClass, sup) == class ];

list[EClass] superclassesOf(EClass class, EPackage pkg) 
  = [ lookup(pkg, #EClass, super) | Ref[EClass] super <- class.eSuperTypes ];

set[EClass] allSuperclassesOf(EClass class, EPackage pkg)
  = { sup, *allSuperclassesOf(sup, pkg) | sup <- superclassesOf(class, pkg) }; 


bool isRequired(EStructuralFeature f) = f.lowerBound >= 1;

bool isMany(EStructuralFeature f) = f.upperBound > 1 || f.upperBound == -1;

EStructuralFeature makeOpt(EStructuralFeature(EAttribute a)) = EStructuralFeature(a[lowerBound=0]);

EStructuralFeature makeOpt(EStructuralFeature(EReference r)) = EStructuralFeature(r[lowerBound=0]);

EStructuralFeature makeRequired(EStructuralFeature(EAttribute a)) = EStructuralFeature(a[lowerBound=1]);

EStructuralFeature makeRequired(EStructuralFeature(EReference r)) = EStructuralFeature(r[lowerBound=1]);

EStructuralFeature makeMany(EStructuralFeature(EAttribute a)) = EStructuralFeature(a[upperBound=-1]);

EStructuralFeature makeMany(EStructuralFeature(EReference r)) = EStructuralFeature(r[upperBound=-1]);

EStructuralFeature makeId(EStructuralFeature(EAttribute a)) = EStructuralFeature(a[iD=true]);


bool isEcoreRef(ref(id(loc l))) = "<l.authority><l.path>" == "www.eclipse.org/emf/2002/Ecore";

default bool isEcoreRef(Ref[EClassifier] _) = false;

str ecoreRefClassifierName(ref(id(loc l))) = l.fragment[2..]; 

// fake lookups to Ecore externals;
// we assume meta models only ever refer to data types not classes 
EClassifier lookupClassifier(EPackage pkg, Ref[EClassifier] r)
  = EClassifier(EDataType(name=ecoreRefClassifierName(r), uid=r.uid))
  when isEcoreRef(r);
  
default EClassifier lookupClassifier(EPackage pkg, Ref[EClassifier] r)
  = lookup(pkg, #EClassifier, r);

