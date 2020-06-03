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
import Boolean;

/*
 Consistency checks (for TyphonML)
  - Containment can not be many-to-many (IOW: target of containment with opposite should be [1])
  - inverse specified on one side only, or they must be consistent in terms of role names.
*/

// abstraction over TyphonML, to be extended with back-end specific info in the generic map
data Schema
  = schema(Rels rels, Attrs attrs, Placement placement = {}, Attrs customs = {}, ChangeOps changeOperators = {},
    Pragmas pragmas = {});

alias Rel = tuple[str from, Cardinality fromCard, str fromRole, str toRole, Cardinality toCard, str to, bool containment];
alias Rels = set[Rel];
alias Attrs = rel[str from, str name, str \type];
alias ChangeOps = list[ChangeOp];
alias ChangeOp = tuple[str name, list[str] properties];

data DB = cassandra() | mongodb() | sql() | hyperj() | recombine() | unknown() | typhon();

alias Place = tuple[DB db, str name];

alias Placement = rel[Place place, str entity];

alias Pragmas = rel[str dbName, Option option];

data Option
  = indexSpec(str name, rel[str entity, str feature] features);


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

bool isImplicitRole(str role) = endsWith(role, "^");

set[Message] schemaSanity(Schema s, loc src) {
  set[Message] msgs = {};

  msgs += { error("Not all entities assigned to backend in TyphonML model: <entities(s) - (s.placement<entity>)>", src) | !(entities(s) <= s.placement<entity>) };
  // todo: maybe more

  return msgs;
}

Placement model2placement(Model m)
  = ( {} | it + place(db, m) | Database db <- m.databases );

Pragmas model2pragmas(Model m)
// ambiguous:  = ( {} | it + *pragmas(db, m) | Database db <- m.databases );
  = { *pragmas(db, m) | Database db <- m.databases };




Pragmas pragmas(Database(RelationalDB(str name, list[Table] tables)), Model m) {
  prags = {};
  for (Table tbl <- tables, just(IndexSpec ind) := tbl.indexSpec) {
    str ent = lookup(m, #Entity, tbl.entity).name;
    ftrs = { <ent, lookup(m, #Attribute, a).name> | Ref[Attribute] a <- ind.attributes };
    ftrs += { <ent, lookup(m, #Relation, r).name> | Ref[Relation] r <- ind.references };
    prags += {<name, indexSpec(ind.name, ftrs)>};
  }
  return prags;
}

default Pragmas pragmas(Database _, Model _) = {};

// NB: the place function is an extension point.

Placement place(Database(RelationalDB(str name, list[Table] tables)), Model m)
  = {<<sql(), name>, lookup(m, #Entity, t.entity).name> | Table t <- tables };

Placement place(Database(DocumentDB(str name, list[Collection] colls)), Model m)
  = {<<mongodb(), name>, lookup(m, #Entity, c.entity).name> | Collection c <- colls };


Placement place(Database(KeyValueDB(str name, list[KeyValueElement] elts)), Model m) {

 set[str] props = {};

 for (KeyValueElement e <- elts) {
   for (Ref[Attribute] ref <- e.values, Attribute a0 := lookup(m, #Attribute, ref)) {
     if (Entity e <- m.entities, EntityAttributeKind(Attribute a) <- e.attributes, a == a0) {
        props += {"<e.name>.<a.name>"};
     }
     else {
       throw "Could not find owner entity of attribute <a0>";
     }
   }
 }

 return { <<cassandra(), name>, p> | str p <- props };
}
  //= {<<cassandra(), name>, lookup(m, #Attribute, c.entity).name> | KeyValueElement e <- elts };


default Placement place(Database db, Model m) {
  throw "Unsupported database: <db>";
}


Schema model2schema(Model m)
  = inferAuxEntities(schema(model2rels(m), model2attrs(m),
       customs = model2customs(m), 
       placement =model2placement(m),
       pragmas = model2pragmas(m),
       changeOperators = model2changeOperators(m)));

str keyValEntity(str db, str ent) = "<ent>__<db>";

str keyValRole(str db, str ent) = "<db>__";


Schema inferAuxEntities(Schema s) {
  /*
  KeyValueDB normalization:
   - attributes that are mapped to cassandra:
      - remove them from entity
      - add to new entity

  */

  rel[str, str, str] cassandraAttrs
    = { <db, ent, name> | <<cassandra(), str db>, str attr> <- s.placement,
         [str ent, str name] := split(".", attr) };

  // remove the attribute placements
  s.placement -= { p | p:<<cassandra(), str _>, str _> <- s.placement };


  // for each db/entity pair
  for (<str db, str ent> <- cassandraAttrs<0,1>) {
    set[str] names = cassandraAttrs[db][ent];
    str newEnt = keyValEntity(db, ent);

    // create new attrs, while old attrs still there
    Attrs newAttrs = { <newEnt, n, t> | str n <- names,
      <ent, n, str t> <- s.attrs };

    // remove old attrs
    s.attrs -= {  <ent, n, t> | str n <- names,  <ent, n, str t> <- s.attrs  };

    // add containment
    s.rels += {<ent, \one(), keyValRole(db, ent), "", \one(), newEnt, true>};

    // add new attrs
    s.attrs += newAttrs;

    // add new placement
    s.placement += {<<cassandra(), db>, newEnt>};
  }




  return s;
}

ChangeOps model2changeOperators(Model m) {
  ChangeOps result = [];

  for(ChangeOperator op <- m.changeOperators){
  	switch(op){
  		case ChangeOperator(AddEntity a):{
  			result += <"addEntity", [a.name]>;
  		}
  		case ChangeOperator(RenameEntity chop):{
  			result += <"renameEntity", [lookup(m, #Entity, chop.entityToRename).name, chop.newEntityName]>;
  		}
  		case ChangeOperator(ChangeRelationCardinality chop):{
  			card = cardToText(chop.newCardinality);
  			result += <"changeRelationCardinality", [lookup(m, #Relation, chop.relation).name, card]>;
  		}
  		case ChangeOperator(ChangeRelationContainement chop):{
  			result += <"changeRelationContainement", [lookup(m, #Relation, chop.relation).name, toString(chop.newContainment)]>;
  		}
  		case ChangeOperator(ChangeAttributeType chop):{
  			attr = lookup(m, #EntityAttribute, chop.attributeToChange);

  			entity = null();
  			if (Entity e <- m.entities, EntityAttribute a <- e.attributes, a.uid == attr.uid) {
			  entity = e;
			}

  			typ = lookup(m, #DataType, attr.\type);
  			result += <"changeAttributeType", [entity.name, attr.name, typ.name]>;
  		}
  		case ChangeOperator(DisableRelationContainment chop):{
  			result += <"disableRelationContainment", [lookup(m, #Relation, chop.relation).name]>;
  		}
  		case ChangeOperator(DisableBidirectionalRelation chop):{
  			result += <"disableBidirectionalRelation", [lookup(m, #Relation, chop.relation).name]>;
  		}
  		case ChangeOperator(EnableRelationContainment chop):{
  			result += <"enableRelationContainment", [lookup(m, #Relation, chop.relation).name]>;
  		}
  		case ChangeOperator(EnableBidirectionalRelation chop):{
  			result += <"enableBidirectionalRelation", [lookup(m, #Relation, chop.relation).name]>;
  		}
		case ChangeOperator(MergeEntity chop):{
			e1 = lookup(m, #Entity, chop.firstEntityToMerge);
			e2 = lookup(m, #Entity, chop.secondEntityToMerge);

  			result += <"mergeEntity", [e1.name, e2.name, chop.newEntityName]>;
  		}
  		case ChangeOperator(MigrateEntity chop):{
			e1 = lookup(m, #Entity, chop.entity);
			db = lookup(m, #Database, chop.newDatabase);

  			result += <"migrateEntity", [e1.name, db.name]>;
  		}
		case ChangeOperator(RemoveAttribute chop):{
			attr = lookup(m, #EntityAttribute, chop.attributeToRemove);
  			entity = null();
  			if (Entity e <- m.entities, EntityAttribute a <- e.attributes, a.uid == attr.uid) {
			  entity = e;
			}

  			result += <"removeAttribute", [entity.name, attr.name]>;
  		}
  		case ChangeOperator(RemoveEntity chop):{
  			entity = lookup(m, #Entity, chop.entityToRemove);
  			result += <"removeEntity", [entity.name]>;
  		}
  		case ChangeOperator(RemoveRelation chop):{
  			rela = lookup(m, #Relation, chop.relationToRemove);
  			entity = lookup(m, #Entity, rela.\type);

  			result += <"removeRelation", [entity.name, rela.name]>;
  		}
  		case ChangeOperator(RenameAttribute chop):{
  			attr = lookup(m, #EntityAttribute, chop.attributeToRename);
  			entity = null();
  			if (Entity e <- m.entities, EntityAttribute a <- e.attributes, a.uid == attr.uid) {
			  entity = e;
			}

  			result += <"renameAttribute", [entity.name, attr.name, chop.newName]>;
  		}
  		case ChangeOperator(RenameEntity chop): {
  			entity = lookup(m, #Entity, chop.entityToRename);
  			result += <"renameEntity", [entity.name, chop.newEntityName]>;
  		}
  		case ChangeOperator(RenameRelation chop): {
  			rela = lookup(m, #Relation, chop.relationToRename);
  			entity = lookup(m, #Entity, rela.\type);

  			result += <"renameRelation", [entity.name, rela.name, chop.newRelationName]>;
  		}


  		case ChangeOperator(AddAttribute chop): {
  			entity = lookup(m, #Entity, chop.ownerEntity);
  			typ = lookup(m, #DataType, chop.\type);

  			result += <"addAttribute", [entity.name, chop.name, typ.name]>;
  		}

  		case ChangeOperator(AddRelation chop): {
  			entity = lookup(m, #Entity, chop.ownerEntity);
  			typ = lookup(m, #Entity, chop.\type);

  			result += <"addAttribute", [entity.name, chop.name, typ.name]>;
  		}
  		case ChangeOperator(SplitEntityHorizontal chop): {
  			entity = lookup(m, #Entity, chop.sourceEntity);
  			attr = lookup(m, #Attribute, chop.attrs);


  			result += <"splitEntityHorizontal", [chop.newEntityName, entity.name, attr.name, chop.expression]>;
  		}
  		case ChangeOperator(SplitEntityVertical chop): {
  			entity = lookup(m, #Entity, chop.entity1);

  			l_attr = [];
  			for(lang::ecore::Refs::Ref[Attribute] attr <- chop.attributeList){
  				l_attr += [(lookup(m, #EntityAttribute, attr).name)];
  			};

  			l = [chop.entity2name, entity.name] + l_attr;
  			result += <"splitEntityVertical", l>;
  		}

  	}
  }


  return result;
}

str builtinDataType2str(DataType dt) {
  str typeName = "";
  switch (dt) {
    case DataType(IntType()): typeName = "int";
    case DataType(BigintType()): typeName = "bigint";
    case DataType(StringType(maxSize = int n)): typeName = "string(<n>)";
    case DataType(BlobType()): typeName = "blob";
    case DataType(BoolType()): typeName = "bool";
    case DataType(TextType()): typeName = "text";
    case DataType(DateType()): typeName = "date";
    case DataType(PointType()): typeName = "point";
    case DataType(DatetimeType()): typeName = "datetime";
    case DataType(PolygonType()): typeName = "polygon";
    case DataType(FloatType()): typeName = "float";
    case DataType(ft:FreetextType(list[NlpTask] tasks)):  {
      typeName = "freetext[";
      typeName += intercalate(", ",  [ "<getName(t.\type)>[<t.workflowName>]" | NlpTask t <- tasks ]);
      typeName += "]";
    }
    default: throw "Unknown primitive data type: <dt>";
  }
  return typeName;
}

Attrs model2attrs(Model m) {
  Attrs result = {};
  for (Entity(str from, list[EntityAttributeKind] attrs, _, _, _) <- m.entities, EntityAttributeKind(Attribute a) <- attrs) {
      DataType dt = a.\type; //lookup(m, #DataType, a.\type);

      str typeName = builtinDataType2str(dt);


      result += {<from, a.name, typeName>};
  }

  for (Entity(str from, list[EntityAttributeKind] attrs, _, _, _) <- m.entities, EntityAttributeKind(CustomAttribute a) <- attrs) {
      CustomDataType dt = lookup(m, #CustomDataType, a.\type);
      result += {<from, a.name, dt.name>};
  }
  return result;
}

Attrs model2customs(Model m) {
  Attrs result = {};
  for (CustomDataType(str from, list[SuperDataType] elements) <- m.customDataTypes) {
  	for (SuperDataType e <- elements) {
  	  str dtName = "";
  	  if (e has simpleDataType) {
  	    dtName = builtinDataType2str(e.simpleDataType.\type);
  	  }
  	  else {
  	    dtName = lookup(m, #CustomDataType, e.complexDataType.\type).name;
  	  }

      //assert (DataType(PrimitiveDataType(_)) := dt || DataType(CustomDataType, _(_)) := dt) :
      //	 "Only built-in and custom primitives allowed for elements (for now).";
      result += {<from, e.name, dtName>};
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
  for (Entity(str from, _, list[Relation] rels, _, _) <- m.entities) {
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

@doc{Find the (unique [we assume]) path to `entity` by following ownership links down from roots}
tuple[str, list[str]] localPathToEntity(str entity, Schema s, Place p) {

  list[str] pathTo(str from, str to) {
    if (<from, _, str fromRole, _, _, to, true> <- s.rels) {
      return [fromRole];
    }
    for (<str from2, _, str fromRole, _, _, to, true> <- s.rels, <p, from2> <- s.placement) {
      if (list[str] sub := pathTo(from, from2), sub != []) {
        return sub + [fromRole];
      }
    }
    return [];
  }

  for (str e <- localRoots(s, p)) {
    if (list[str] path := pathTo(e, entity), path != []) {
      return <e, path>;
    }
  }

  return <entity, []>;

}

set[str] localRoots(Schema s, Place p)
  = { e | str e <- entities(s), <p, e> <- s.placement,  !ownedLocally(e, s, p) };

bool ownedLocally(str entity, Schema s, Place p)
  = any(<str from, _, _, _, _, entity, true> <- s.rels, <p, from> <- s.placement);



Rels trueCrossRefs(Rels rels)
  = { <from, fromCard, fromRole, toRole, toCard, to, false> |
    <str from, Cardinality fromCard, str fromRole, str toRole, Cardinality toCard, str to, false> <- rels,
      <to, toCard, toRole, fromRole, fromCard, from, true> notin rels };

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

str cardToText(Cardinality c){
	switch(c){
  		case one_many(): return "one_many";
  		case zero_many(): return "zero_many";
  		case zero_one() : return "zero_one";
  		case \one() : return "one";
  	}
}
