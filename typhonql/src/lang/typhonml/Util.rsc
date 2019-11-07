@doc{
Utility functions and data types to abstract over details of the Ecore representation
of TyphonML.
}
module lang::typhonml::Util

import lang::typhonml::TyphonML;
import lang::typhonml::XMIReader;
import lang::ecore::Refs;

import ParseTree;
import IO;
import Set;
import List;
import String;
import Node;
import Message;

/*
 Consistency checks (for TyphonML)
  - Containment can not be many-to-many (IOW: target of containment with opposite should be [1]) 
  - inverse specified on one side only, or they must be consistent in terms of role names.
*/

// abstraction over TyphonML, to be extended with back-end specific info in the generic map
data Schema
  = schema(Rels rels, Attrs attrs, Placement placement = {}, Attrs elements = {}, map[str, value] config = ());


alias Rel = tuple[str from, Cardinality fromCard, str fromRole, str toRole, Cardinality toCard, str to, bool containment];
alias Rels = set[Rel];
alias Attrs = rel[str from, str name, str \type];

data DB = mongodb() | sql() | hyperj() | recombine() | unknown() | typhon();

alias Place = tuple[DB db, str name];

alias Placement = rel[Place place, str entity];


void dumpSchema(Schema s) {
  println(ppSchema(s));
}

str ppSchema(Schema s) {
  str txt = "";
  for (str ent <- s.rels<0> + s.attrs<0>, <Place p, ent> <- s.placement) {
    txt += "entity <ent> @ <getName(p.db)>/<p.name> {\n";
    for (<ent, str fld, str typ> <- s.attrs) {
      txt += "  <fld>: <typ>\n";
    }
    for (<ent, Cardinality card, str role, str toRole, Cardinality toCard, str to, bool cont> <- s.rels) {
      txt += "  <role><cont ? ":" : " -\>"> <to><card2str(card)> <if (toRole != "") {>(inv=<toRole><card2str(toCard)>)<}>\n";
    }
    txt += "}\n\n";
  } 
  return txt;
}

str card2str(one_many()) = "+";
str card2str(zero_many()) = "*";
str card2str(zero_one()) = "?";
str card2str(\one()) = "";

Schema loadSchema(loc l) = model2schema(loadTyphonML(l));
  
Schema myDbSchema() = loadSchema(|project://typhonql/src/newmydb4.xmi|);

Rels myDbToRels() = model2rels(load(#Model, |project://typhonql/src/lang/newmydb4.xmi|));

set[str] entities(Schema s) = s.rels<0> + s.attrs<0>;

set[Message] schemaSanity(Schema s, loc src) {
  set[Message] msgs = {};
  
  msgs += { error("Not all entities assigned to backend in TyphonML model", src) | !(entities(s) <= s.placement<entity>) }; 
  // todo: maybe more  
  
  return msgs;
}

Placement model2placement(Model m) 
  = ( {} | it + place(db, m) | Database db <- m.databases );  

// NB: the place function is an extension point.

Placement place(Database(RelationalDB(str name, list[Table] tables)), Model m) 
  = {<<sql(), name>, lookup(m, #Entity, t.entity).name> | Table t <- tables };
  
Placement place(Database(DocumentDB(str name, list[Collection] colls)), Model m) 
  = {<<mongodb(), name>, lookup(m, #Entity, c.entity).name> | Collection c <- colls };

default Placement place(Database db, Model m) {
  throw "Unsupported database: <db>";
} 


Schema model2schema(Model m)
  = schema(model2rels(m), model2attrs(m), elements = model2elements(m), placement=model2placement(m));



Attrs model2attrs(Model m) {
  Attrs result = {};
  for (DataType(Entity(str from, list[Attribute] attrs, _, _)) <- m.dataTypes) {
    for (Attribute a <- attrs) {
      DataType dt = lookup(m, #DataType, a.\type);
      assert (DataType(PrimitiveDataType(_)) := dt || DataType(CustomDataType(_,_)) := dt) :
      	 "Only built-in and custom primitives allowed for attributes (for now).";
      result += {<from, a.name, dt.name>};
    }
  }
  return result;
}

Attrs model2elements(Model m) {
  Attrs result = {};
  for (DataType(CustomDataType(str from, list[DataTypeItem] elements)) <- m.dataTypes) {
  	for (DataTypeItem e <- elements) {
      DataType dt = lookup(m, #DataType, e.\type);
      assert (DataType(PrimitiveDataType(_)) := dt || DataType(CustomDataType, _(_)) := dt) :
      	 "Only built-in and custom primitives allowed for elements (for now).";
      result += {<from, e.name, dt.name>};
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
  // todo: freetextAttributes
  for (DataType(Entity(str from, _, _, list[Relation] rels)) <- m.dataTypes) {
    for (r:Relation(str fromRole, Cardinality fromCard) <- rels) {
      Entity target = lookup(m, #Entity, r.\type);
      str to = target.name;
      str toRole = "<fromRole>^"; 
      Cardinality toCard = zero_one(); // check: is this the default?
      
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


Rels symmetricReduction(Rels rels) {
  // filter out symmetric bidir relations
  // if containment, that one gets preference
  // else, it doesn't matter.
  // assumes sanityCheckOpposites;
  removed = {};
  for (t1:<str e1, Cardinality c1, str r1, str r2, Cardinality c2, str e2, _> <- rels) {
    t2 = <e2, c2, r2, r1, c1, e1, false>;
    if (t1 != t2, t1 notin removed) {
      rels -= { t2 };
      removed += {t2};
    }
  }
  return rels;
}

Rels sanityCheckOpposites(Rels rels) {
  /*
   check that if we have <e1, c1, r1, r2 != "", c2, e2, b> in rels,
   there's also <e2, c2, r2, r1, c1, e1, !b> (if b was true, otherwise it can be either true/false).
  */
  for (t1:<str e1, Cardinality c1, str r1, str r2, Cardinality c2, str e2, bool b> <- rels, r2 != "") {
    if (b) { // one of them is containment
      t2 = <e2, c2, r2, r1, c1, e1, !b>;
      if (t2 notin rels) {
        println("Relation <t1> is in rels, but not <t2>");
      }
      t2 = <e2, c2, r2, r1, c1, e1, b>;
      if (t2 in rels) {
        println("Relation <t1> is in rels, but also <t2> (containment can only be one way)");
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


void printOutPossibleRelations() {
  combs =  {"A contains", "A references"} join 
          {"one B", "zero or one B", "zero or many B"} join 
          {/*"where B contains", */"where B references"} join
          {"one A", "zero or one A", "zero or many A"} join
          {"and B is local", "and B is outside"};
          
  // filter out illegal opposites:
  // if A contains, B cannot contain (and vice versa)
  combs -= { <from, card, to, toCard, local> |
        <str from, str card, str to, str toCard, str local> <- combs,
        from == "A contains", to == "where B contains" };


  // if A contains, B's opposite must be one (and vice versa)
  combs -= { <from, card, to, toCard, local> |
        <str from, str card, str to, str toCard, str local> <- combs,
        from == "A contains", toCard != "one A" }; 
        
  combs -= { <from, card, to, toCard, local> |
        <str from, str card, str to, str toCard, str local> <- combs,
        to == "where B contains", card != "one B" }; 

  // (optional/for now) if A contains, B must be local     
  combs -= { <from, card, to, toCard, local> |
        <str from, str card, str to, str toCard, str local> <- combs,
        from == "A contains", local == "and B is outside" }; 
          
  println("Size: <size(combs)>");
  iprintln(sort(toList(combs)));     
}


