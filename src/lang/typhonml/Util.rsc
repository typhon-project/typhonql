module lang::typhonml::Util


import lang::typhonml::TyphonML;
import lang::ecore::Refs;
import lang::ecore::IO;
import IO;

/*
 Consistency checks (for TyphonML)
  - Containment can not be many-to-many (IOW: target of containment with opposite should be [1]) 
  - inverse specified on one side only, or they must be consistent in terms role names.
*/

alias Rels = rel[str from, Cardinality fromCard, str fromRole, str toRole, Cardinality toCard, str to, bool containment];
alias Attrs = rel[str from, str name, str \type];


Attrs model2attrs(Model m) {
  Attrs result = {};
  for (DataType(Entity(str from, list[Attribute] attrs, _)) <- m.dataTypes) {
    for (Attribute a <- attrs) {
      DataType dt = lookup(m, #DataType, a.\type);
      assert DataType(PrimitiveDataType(_)) := dt : "Only built-in primitives allowed for attributes (for now).";
      result += {<from, a.name, dt.name>};
    }
  }
  return result;
}


@doc{
This functions flattens the relational structure of a TyphonML model into a flat set
of relations including opposite management.
It's redudant in that it might include two tuples for the same bidirectional relation, but this
will ease querying later down the line.
}
Rels model2rels(Model m) {
  Rels result = {};
  for (DataType(Entity(str from, _, list[Relation] rels)) <- m.dataTypes) {
    for (r:Relation(str fromRole, Cardinality fromCard) <- rels) {
      Entity target = lookup(m, #Entity, r.\type);
      str to = target.name;
      str toRole = "";
      Cardinality toCard = \one(); // check: is this the default?
      
      if (r.opposite != null()) {
        Relation inv = lookup(m, #Relation, r.opposite);
        toRole = inv.name;
        toCard = inv.cardinality;
      }
      else {
        /*
         * If the opposite on r is null(), then the other side might still declare
         * an opposite to the current relation; we look for it here, and include
         * info from the target entity to record the bidirectional relation.
         */
        if (r2:Relation(str x, Cardinality c) <- target.relations, r2.opposite != null(), lookup(m, #Relation, r2.opposite) == r) {
          toRole = x;
          toCard = c; 
        } // otherwise they remain empty/default
      }
      
      
      result += {<from, fromCard, fromRole, toRole, toCard, to, r.isContainment>};  
    }
  }
  return result;
}

Rels sanityCheckOpposites(Rels rels) {
  /*
   check that if we have <e1, c1, r1, r2 != "", c2, e2, b> in rels,
   there's also <e2, c2, r2, r1, c1, e1, !b> (if b was true, otherwise it can be either true/false).
  */
  for (t1:<str e1, Cardinality c1, str r1, str r2, Cardinality c2, str e2, bool b> <- rels, r2 != "") {
    if (b) {
      t2 = <e2, c2, r2, r1, c1, e1, !b>;
      if (t2 notin rels) {
        println("Relation <t1> is in rels, but not <t2>");
      }
    }
    else {
      if (!(<e2, c2, r2, r1, c1, e1, _> <- rels)) {
        println("Relation <t1> is in rels, but not \<<e2>, <c2>, <r2>, <r1>, <c1>, <e1>, true|false\>");
      }
    }
  } 
  return {};
}


Rels myDbToRels() = model2rels(load(#Model, |project://typhonql/src/lang/typhonml/mydb3.model|));

