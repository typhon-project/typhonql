module lang::ecore::Ecore2ADT

import lang::ecore::Ecore;
import lang::ecore::EcoreUtil;
import lang::ecore::Refs;
import lang::ecore::IO;

import IO;
import ValueIO;
import Type;
import List;
import String;
import analysis::graphs::Graph;
import DateTime;

// TODO: 
// - annotations
// - defaultValues from the metametamodel
// - pkgURI at root data type.

@doc{Generate an Rascal module containing a meta model ADT for `pkg`.
NB: flattenInheritance is only called in this top-level function.}
void writeEcoreADTModule(str moduleName, loc l, EPackage pkg) 
  = writeFile(l, "module <moduleName>
                 '
                 '// Generated code; do not edit.
                 '// Date: <now()>
                 '
                 'import lang::ecore::Refs;
                 'import util::Maybe;
                 'import DateTime;
                 '
                 '<ecore2rsc(flattenInheritance(newRealm(), pkg))>");

@doc{Convert an Ecore EPackage to source code of an equivalent meta model ADT} 
str ecore2rsc(EPackage pkg) 
  = intercalate("\n\n", [ choice2rsc(defs[s]) | Symbol s <- orderADTs(defs) ])
  when 
    defs := package2definitions(pkg);

@doc{Order the definitions in `def` by topological sort wrt dependency}
list[Symbol] orderADTs(map[Symbol, Production] defs) {
  deps = { <s1, s2> | s1 <- defs, /s2:adt(str x, _) := defs[s1], x != "Ref", x != "Id", x != "Maybe" };
  return order(deps);
}

/*
 * Mapping Ecore EPackage meta models to symbol definitions
 */

@doc{Convert an Ecore EPackage to a definitions map as used internally by Rascal} 
map[Symbol, Production] package2definitions(EPackage pkg) 
  = ( p.def: p | EClassifier c <- pkg.eClassifiers,
       EClassifier(EClass _) := c || EClassifier(EDataType(EEnum _)) := c, p := classifier2choice(c, pkg) );

@doc{Map EClass classifier to ADT, including injections for (direct) subclasses}
Production classifier2choice(EClassifier(EClass class), EPackage pkg) {
  Symbol a = adt(class.name, []);
  set[Production] alts = { class2prod(class, pkg) | !class.abstract }
    + { cons(label(class.name, a), [label(fieldName(sub.name), adt(sub.name, []))], 
          [ feature2arg(f, sub, pkg, true)  | f <- sub.eStructuralFeatures, !f.derived, !f.transient ]
          + [label("uid", adt("Id", [])), label("_inject", \bool())]
          , {})  
          | EClass sub <- directSubclassesOf(class, pkg) };
  return choice(a, alts);
}

@doc{Map EEnum classifier to ADT}
Production classifier2choice(EClassifier(EDataType(EEnum enum)), EPackage pkg) {
  Symbol a = adt(enum.name, []);
  set[Production] alts = { cons(label(el.name, a), [], [], {}) | el <- enum.eLiterals };
  return choice(a, alts);
}


@doc{Map an EClass to a constructor production}
Production class2prod(EClass class, EPackage pkg) {
  ps =  [ feature2arg(f, class, pkg, true) | f <- class.eStructuralFeatures, isRequired(f) || isMany(f), !f.derived, !f.transient ];
  kws = [ feature2arg(f, class, pkg, false) | f <- class.eStructuralFeatures, !isRequired(f) && !isMany(f), !f.derived, !f.transient ]
    + [ label("uid", adt("Id", [])) ];
  return cons(label(class.name, adt(class.name, [])), ps, kws, {});
}

@doc{Map structural feature to an "argument" (e.g. parameter or keyword parameter)}
Symbol feature2arg(EStructuralFeature f, EClass c, EPackage pkg, bool req) 
  = label(fieldName(f.name), feature2symbol(f, c, pkg, req));


@doc{Map structural feature to symbol} 
Symbol feature2symbol(EStructuralFeature f, EClass c, EPackage pkg, bool req) {
  Symbol t = type2symbol(f.eType, pkg, f has containment ==> !f.containment, req, isMany(f));
  return isMany(f) ? \list(t) : t;
}


Symbol type2symbol(Ref[EClassifier] typeRef, EPackage pkg, bool xref, bool req, bool many) 
  = classifier2symbol(lookupClassifier(pkg, typeRef), xref, req, many);
  
Symbol classifier2symbol(EClassifier(EDataType(name = str name)), bool xref, bool req, bool many) 
  = prim2symbol(name);

Symbol classifier2symbol(EClassifier(EClass(name = str name)), bool xref, bool req, bool many) 
  = xref ? adt("Ref", [adt(name, [])]) : ((req || many) ? adt(name, []) : adt("Maybe", [adt(name, [])]));

Symbol classifier2symbol(EClassifier(EDataType(EEnum(name = str name))), bool xref, bool req, bool many) = adt(name, []);

Symbol prim2symbol("EBigDecimal") = \real();

Symbol prim2symbol("EDouble") = \real();

Symbol prim2symbol("EFloat") = \real();

Symbol prim2symbol("EBigInteger") = \int();

Symbol prim2symbol("EByte") = \int();

Symbol prim2symbol("EShort") = \int();

Symbol prim2symbol("EInt") = \int();

Symbol prim2symbol("ELong") = \int();

Symbol prim2symbol("EBoolean") = \bool();

Symbol prim2symbol("EBooleanObject") = \bool();

Symbol prim2symbol("EString") = \str();

Symbol prim2symbol("EDate") = \datetime();

Symbol prim2symbol("EEnumerator") = \tuple([label("literal", \str()), label("name", \str()), label("\\value", \int())]);

default Symbol prim2symbol(str d) { throw "Unsupported primitive <d>"; }


/*
 * Formatting abstract ADT grammars to text
 */

str choice2rsc(choice(Symbol a, set[Production] alts)) 
  = "data <a.name>\n  = <intercalate("\n  | ", [ prod2rsc(p) | Production p <- alts ])>
    '  ;";

str prod2rsc(cons(label(str c, _), [label(str x, adt(str sub, []))], 
      [*subs, label("uid", adt("Id", [])), label("_inject", \bool())], _))
  = "<c>(<intercalate("\n      , ", args)>)"
  when fieldName(sub) == x,
    args := [
      "<sub> <x>",
      *[ default4sub(s, x) | s <- subs ],
      "lang::ecore::Refs::Id uid = <x>.uid",
      "bool _inject = true"
    ];

str default4sub(label(str fld, Symbol s), str kid)
  = "<sym2rsc(s)> <fld> = <kid>.<fld>";

default str prod2rsc(cons(label(str c, _), list[Symbol] ps, list[Symbol] kws, _))
  = "<c>(<intercalate("\n      , ", args)>)"
  when
    list[str] args := [ param2rsc(p) | p <- ps ] + [ kwp2rsc(k) | k <- kws ];
    
str param2rsc(label(str name, Symbol s)) = "<sym2rsc(s)> <name>";

str kwp2rsc(label(str name, Symbol s)) = "<sym2rsc(s)> <name> = <default4sym(s)>";

str sym2rsc(\int()) = "int";

str sym2rsc(\bool()) = "bool";

str sym2rsc(\real()) = "real";

str sym2rsc(\str()) = "str";

str sym2rsc(\datetime()) = "datetime";

str sym2rsc(\list(Symbol s)) = "list[<sym2rsc(s)>]";

str sym2rsc(\tuple(list[Symbol] ss)) = "tuple[<intercalate(", ", [ sym2rsc(s) | s <- ss])>]";

str sym2rsc(label(str n, Symbol s)) = "<sym2rsc(s)> <n>";

str sym2rsc(adt(str n, list[Symbol] ps)) 
  = "<qualify(n)><ps != [] ? "[" + intercalate(", ", [ sym2rsc(p) | p <- ps ]) + "]" : "">";
  
str qualify("Maybe") = "util::Maybe::Maybe";
  
str qualify("Ref") = "lang::ecore::Refs::Ref";

str qualify("Id") = "lang::ecore::Refs::Id";
  
default str qualify(str x) = x;
  
str default4sym(\int()) = "0";

str default4sym(\bool()) = "false";

str default4sym(\real()) = "0.0";

str default4sym(\str()) = "\"\"";

str default4sym(\datetime()) = "DateTime::now()"; 

str default4sym(\list(Symbol s)) = "[]";

str default4sym(\label(str _, Symbol s)) = default4sym(s);

str default4sym(\tuple(list[Symbol] ss)) 
  = "\<<intercalate(", ", [ default4sym(s) | s <- ss])>\>";

str default4sym(adt("Ref", list[Symbol] ps)) 
  = "null()";

str default4sym(adt("Id", list[Symbol] ps)) 
  = "noId()";

str default4sym(adt("Maybe", list[Symbol] ps)) 
  = "nothing()";

default str default4sym(adt(str x, list[Symbol] ps)) { throw "No default for ADT <x> we don\'t know"; }


str fieldName(str x) = "\\<uncapitalize(x)>";

