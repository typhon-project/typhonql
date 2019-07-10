module lang::ecore::hutn::Ecore2HUTN

import lang::ecore::Ecore;
import lang::ecore::EcoreUtil;
import lang::ecore::Refs;

import Type;
import DateTime;
import ParseTree;
import Grammar;
import IO;
import String;

import lang::rascal::format::Grammar;

private Symbol myLayout = layouts("Standard");

void writeHUTNModule(str moduleName, loc path, EPackage pkg, str root, str name = pkg.name, str ext = "<pkg.name>_hutn") {
  src = ecore2rascal(pkg, root);
  m = "module <moduleName>
      '
      'extend lang::ecore::hutn::Base;
      'import util::IDE;
      'import ParseTree;
      '
      '// Generated code; do not edit.
      '// Date: <now()>
      '
      '<src>
      '
      'start[<root>] parse<capitalize(name)>(str src, loc l)
      '  = parse(#start[<root>], src, l);
      '
      'void main() {
      '  registerLanguage(\"<name>\", \"<ext>\", parse<capitalize(name)>);
      '}";
      
  writeFile(path, m);
}

str ecore2rascal(EPackage pkg, str root)
  = grammar2rascal(ecore2grammar(pkg, root));

Grammar ecore2grammar(EPackage pkg, str root) 
  = grammar({sort(root)}, ecore2rules(pkg, root));

list[Symbol] nameFor(EClass c, EPackage pkg) = [label("name", lex("Name")), myLayout] 
 when 
   EClass sup <- [c, *allSuperclassesOf(c, pkg)], 
   EStructuralFeature f <- sup.eStructuralFeatures, 
   f.name == "name";

default list[Symbol] nameFor(EClass c, EPackage pkg) = []; 

map[Symbol, Production] ecore2rules(EPackage pkg, str root) {
 
  map[Symbol, Production] defs = ();
 
  for (EClassifier(EClass c) <- pkg.eClassifiers) {
    nt = c.name == root ? \start(sort(c.name)) : sort(c.name);
    kw = lit(c.name);
    fieldNt = sort("<c.name>_Field");
    fields = label("fields", \iter-star-seps(fieldNt, [myLayout]));
    alts = {prod(label(c.name, nt), [kw, myLayout, *nameFor(c, pkg), 
              lit("{"), myLayout, fields, myLayout, lit("}")], {\tag("Foldable"())}) | !c.abstract };
              
              
    // this is funny, for the class nts, we inject the subclasses...          
    alts += { prod(nt, [sort(sub.name)], {\tag("inject"())}) | EClass sub <- directSubclassesOf(c, pkg) };
    defs[nt] = choice(nt, alts); 
    
    // ... and for the field nts we inject the super class fields :-)
    fieldAlts = { feature2prod(f, fieldNt, lookupClassifier(pkg, f.eType)) | EStructuralFeature f <- c.eStructuralFeatures, !f.derived, f.eType != null() /* ??? */ };
    fieldAlts += { prod(fieldNt, [sort("<sup.name>_Field")], {\tag("inject"())}) | EClass sup <- superclassesOf(c, pkg) };
    defs[fieldNt] = choice(fieldNt, fieldAlts);
  } 
  
  return defs;
}

Production feature2prod(f:EStructuralFeature(EReference r), Symbol nt, EClassifier eType) 
  = prod(label(r.name, nt), [lit(r.name), myLayout, lit(":"), myLayout, *ref2sym(r, eType, isMany(f))], {});

Production feature2prod(f:EStructuralFeature(EAttribute a), Symbol nt, EClassifier eType) 
  = prod(label(a.name, nt), [lit(a.name), myLayout, lit(":"), myLayout, *prim2sym(eType.name, isMany(f))], {});


list[Symbol] ref2sym(EReference r, EClassifier eType, bool many)
  = many ? [lit("["), myLayout, \iter-star-seps(ref2sym(r, eType), [myLayout]), myLayout, lit("]")] : [ref2sym(r, eType)]; 

Symbol ref2sym(EReference r, EClassifier eType)
  = r.containment ? sort(eType.name) : \parameterized-sort("Ref", [sort(eType.name)]);

list[Symbol] prim2sym(str prim, bool many) 
  = many ? [lit("["), myLayout, \iter-star-seps(prim2sym(prim), [myLayout]), myLayout, lit("]")] : [prim2sym(prim)]; 

Symbol prim2sym("EBigDecimal") = lex("Real");

Symbol prim2sym("EDouble") = lex("Real");

Symbol prim2sym("EFloat") = lex("Real");

Symbol prim2sym("EBigInteger") = lex("Int");

Symbol prim2sym("EByte") = lex("Int");

Symbol prim2sym("EShort") = lex("Int");

Symbol prim2sym("EInt") = lex("Int");

Symbol prim2sym("ELong") = lex("Int");

Symbol prim2sym("EBoolean") = lex("Bool");

Symbol prim2sym("EString") = lex("Str");

default Symbol prim2sym(str s) { throw "Unsupported Ecore type: <s>"; }
