/********************************************************************************
* Copyright (c) 2018-2020 CWI & Swat.engineering 
*
* This program and the accompanying materials are made available under the
* terms of the Eclipse Public License 2.0 which is available at
* http://www.eclipse.org/legal/epl-2.0.
*
* This Source Code may also be made available under the following Secondary
* Licenses when the conditions for such availability set forth in the Eclipse
* Public License, v. 2.0 are satisfied: GNU General Public License, version 2
* with the GNU Classpath Exception which is
* available at https://www.gnu.org/software/classpath/license.html.
*
* SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0
********************************************************************************/

module lang::typhonql::References

import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::Script;
import lang::typhonql::Session;
import lang::typhonql::TDBC;
import lang::typhonql::Order;

import lang::typhonql::relational::SQL;
import lang::typhonql::relational::Util;
import lang::typhonql::relational::SQL2Text;

import lang::typhonql::neo4j::Neo;
import lang::typhonql::neo4j::Neo2Text;
import lang::typhonql::neo4j::NeoUtil;

import lang::typhonql::mongodb::DBCollection;


import IO;
import List;
import String;
import util::Maybe;

// TODO: if junction tables are symmetric, i.e. normalized name order in junctionTableName
// then we don't have to swap arguments if maintaining the inverse at outside sql db.

data Pointer
	= pointerUuid(str name)
	| pointerPlaceholder(str name);
	

Maybe[Pointer] expr2pointer((Expr) `<UUID uuid>`) = Maybe::just(uuid2pointer(uuid));
Maybe[Pointer] expr2pointer((Expr) `<PlaceHolder ph>`) = Maybe::just(placeholder2pointer(ph));
default Maybe[Pointer] expr2pointer(Expr _) = Maybe::nothing();

Pointer uuid2pointer(UUID uuid) = pointerUuid("<uuid.part>");
Pointer placeholder2pointer(PlaceHolder ph) = pointerPlaceholder("<ph.name>");

str uuid2str(UUID ref) = "<ref.part>";

list[Pointer] refs2pointers(list[PlaceHolderOrUUID] refs) =
	[uuid2pointer(uuid) |(PlaceHolderOrUUID) `<UUID uuid>` <- refs]
	+ [placeholder2pointer(ph) |(PlaceHolderOrUUID) `<PlaceHolder ph>` <- refs];
	

list[Step] updateIntoJunctionSingleContainment(str dbName, str from, str fromRole, str to, str toRole, SQLExpr src, SQLExpr trg, Bindings params) {
  return removeFromJunctionByKid(dbName, from, fromRole, to, toRole, trg, params)
    + insertIntoJunction(dbName, from, fromRole, to, toRole, src, [trg], params);
}

list[Step] updateIntoJunctionSingle(str dbName, str from, str fromRole, str to, str toRole, SQLExpr src, SQLExpr trg, Bindings params) {
  return removeFromJunction(dbName, from, fromRole, to, toRole, src, params)
    + insertIntoJunction(dbName, from, fromRole, to, toRole, src, [trg], params);
}

list[Step] updateIntoJunctionMany(str dbName, str from, str fromRole, str to, str toRole, SQLExpr src, list[SQLExpr] trgs, Bindings params) {
  return removeFromJunction(dbName, from, fromRole, to, toRole, src, params)
      + insertIntoJunction(dbName, from, fromRole, to, toRole, src, trgs, params);
}

list[Step] neoReplaceEnd(
  str dbName,
  str edgeEntity,
  str targetEntity,
  str role,
  NeoExpr subject,
  NeoExpr target,
  Bindings params,
  Schema schema) {
   	str procedureName =
   		(relationIsFromEdge(dbName, edgeEntity, role, schema))?"from":"to";  
	NeoStat theNeoUpdate = 
		\nMatchQuery(
  			[nMatch([nPattern(nNodePattern("__n1", [], []), 
  				[nRelationshipPattern(nDoubleArrow(), "__r1",  edgeEntity, [nProperty(typhonId(edgeEntity), subject)],
  				 nNodePattern("__n2", [], []))]
  				)], []),
  		     nMatch([nPattern(nNodePattern("__n3", [], [nProperty(typhonId(targetEntity), target)]), [])], []),
  		     nCallYield("apoc.refactor.<procedureName>", [nVariable("__r1"), nVariable("__n3")], ["input", "output"])],
  		     [nVariable("input"), nVariable("output")]);
	steps =[ step(dbName, neo(executeNeoUpdate(dbName, neopp(theNeoUpdate))), params)];
	return steps;
}

list[Step] insertIntoJunction(str dbName, str from, str fromRole, str to, str toRole, SQLExpr src, list[SQLExpr] trgs, Bindings params) {
  str tbl = junctionTableName(from, fromRole, to, toRole);
  return  [ step(dbName, 
           sql(executeStatement(dbName, 
             pp(\insert(tbl
                  , [junctionFkName(from, fromRole), junctionFkName(to, toRole)]
                  , [src, trg])))), params) | SQLExpr trg <- trgs ];
}

list[Step] removeFromJunction(str dbName, str from, str fromRole, str to, str toRole, SQLExpr src, Bindings params) {
  str tbl = junctionTableName(from, fromRole, to, toRole);
  return  [ step(dbName, 
           sql(executeStatement(dbName, 
             pp(delete(tbl,
               [ where([equ(column(tbl, junctionFkName(from, fromRole)), src)]) ])))), params) ];
}

list[Step] removeFromJunctionByKid(str dbName, str from, str fromRole, str to, str toRole, SQLExpr trg, Bindings params) {
  str tbl = junctionTableName(from, fromRole, to, toRole);
  return  [ step(dbName, 
           sql(executeStatement(dbName, 
             pp(delete(tbl,
               [ where([equ(column(tbl, junctionFkName(to, toRole)), trg)]) ])))), params) ];
}

list[Step] removeFromJunction(str dbName, str from, str fromRole, str to, str toRole, SQLExpr src, list[SQLExpr] trgs, Bindings params) {
  str tbl = junctionTableName(from, fromRole, to, toRole);
  return  [ step(dbName, 
           sql(executeStatement(dbName, 
             pp(delete(tbl,
               [ where([equ(column(tbl, junctionFkName(from, fromRole)), src),
                    \in(column(tbl, junctionFkName(to, toRole)), [ trg | SQLExpr trg <- trgs ])]) ])))), params) ];
}

list[Step] cascadeViaJunction(str dbName, str from, str fromRole, str to, str toRole, SQLExpr src, Bindings params) {
  // src is a from
  str tbl = junctionTableName(from, fromRole, to, toRole);
  
  SQLStat stat = deleteJoining([tbl, tableName(to)],
    [ where([equ(column(tbl, junctionFkName(from, fromRole)), src),
         equ(column(tableName(to)), column(junctionFkName(to, toRole)))])]);
         
  return [step(dbName, sql(executeStatement(dbName, pp(stat))), params)];
}


list[Step] updateObjectPointer(str dbName, str coll, str role, Cardinality card, DBObject subject, DBObject target, Bindings params) {
    return [
      step(dbName, mongo( 
         findAndUpdateOne(mongoDBName(dbName), coll,
          pp(object([<"_id", subject>])), 
          pp(object([<"$set", object([<role, target>])>])))), params)
          ];
}


list[Step] insertObjectPointer(str dbName, str coll, str role, Cardinality card, DBObject subject, DBObject trg, Bindings params) {
  if (card in {zero_many(), one_many()}) {
    return [
      step(dbName, mongo( 
         findAndUpdateOne(mongoDBName(dbName), coll,
          pp(object([<"_id", subject>])), 
          pp(object([<"$addToSet", object([<role, trg>])>])))), params)
          ];
  }
  return [
      step(dbName, mongo( 
         findAndUpdateOne(mongoDBName(dbName), coll,
          pp(object([<"_id", subject>])), 
          pp(object([<"$set", object([<role, trg>])>])))), params)
          ];
  
}

list[Step] insertObjectPointers(str dbName, str coll, str role, Cardinality card, DBObject subject, list[DBObject] targets, Bindings params) {
    return [
      step(dbName, mongo( 
         findAndUpdateOne(mongoDBName(dbName), coll,
          pp(object([<"_id", subject>])), 
          pp(object([<"$addToSet", object([<role, object([<"$each", array([ trg | DBObject trg <- targets ])>])>])>])))), params)
          ];
}

list[Step] cascadeViaInverse(str dbName, str coll, str role, DBObject parent, Bindings params) {
  DBObject q = object([<role, parent>]);
  return [step(dbName, mongo(deleteMany(mongoDBName(dbName), coll, pp(q))), params)];
}

bool relationIsFromEdge(str dbName, str edge, str relation, Schema s) {
	if (<dbName, graphSpec(edges)> <-s.pragmas) {
		if (<edge, relation, _> <- edges)
			return true;
		if (<edge, _, relation> <- edges)
			return false;
	}
	throw "Wrong relation for a graph-based entity";
}

list[Step] cascadeViaInverseNeo(str dbName, str edge, str role, str \node, NeoExpr parent, Bindings params, Schema s) {
  NeoNodePattern n1 = nNodePattern("__n1", [], []);
  NeoNodePattern n2 = nNodePattern("__n2", [], []);
  
  bool fromEdge = relationIsFromEdge(dbName, edge, role, s); 
  NeoProperty prop = nProperty(graphPropertyName("@id", \node), parent);
  
  if (fromEdge)
  	n1.properties += [prop];
  else 
  	n2.properties += [prop];
   
  stat = nMatchUpdate(
  	Maybe::just(nMatch([nPattern(n1, 
 			[nRelationshipPattern(nDoubleArrow(), "__r1", edge, [  ], n2)])], [])), 
 		nDelete([nVariable("__r1")]),
 		[nLit(nBoolean(true))]);
 		
  return [step(dbName, neo(executeNeoUpdate(dbName, neopp(stat))), params)];
}


list[Step] removeAllObjectPointers(str dbName, str coll, str role, Cardinality card, DBObject target, Bindings params) {
  if (card in {zero_many(), one_many()}) {
    return [
      step(dbName, mongo( 
         findAndUpdateMany(mongoDBName(dbName), coll,
          pp(object([])), 
          pp(object([<"$pull", 
               object([<role, 
                 object([<"$in", array([ target ])>])>])>])))), params)
          ];
  }
  return [
      step(dbName, mongo( 
         findAndUpdateMany(mongoDBName(dbName), coll,
          pp(object([<role, target>])), 
          pp(object([<"$set", object([<role, DBObject::null()>])>])))), params)
      ];
}

list[Step] removeObjectPointers(str dbName, str coll, str role, Cardinality card, DBObject subject, list[DBObject] targets, Bindings params) {
    return [
      step(dbName, mongo( 
         findAndUpdateOne(mongoDBName(dbName), coll,
          pp(object([<"_id", subject>])), 
          pp(object([<"$pull", 
               object([<role, 
                 object([<"$in", array([ trg | DBObject trg <- targets ])>])>])>])))), params)
          ];
}

list[Step] deleteManyMongo(str dbName, str coll, list[DBObject] objs, Bindings params) {
  return [
    // todo: use deleteMany and $in
    step(dbName, mongo(
       deleteOne(mongoDBName(dbName), coll, pp(object([<"_id", obj>])))), params)
       | DBObject obj <- objs ];
}

list[Step] updateNeoPointer(str dbName, str from, str fromRole, str to, str toRole, NeoExpr subject, NeoExpr target, Bindings params) {
      NeoStat update = 
      \nMatchUpdate(Maybe::just(nMatch([], [], [nLit(nBoolean(true))])), 
      		nCreate(nPattern(nNodePattern("__n1", [], [ nProperty(graphPropertyName("@id", from), subject)]), 
      			[nRelationshipPattern(nDoubleArrow(), "__r1", toRole, [], nNodePattern("__n2", [], [nProperty(graphPropertyName("@id", to), target)]))])));
    return [step(dbName, neo(update), params)];
      /*
         findAndUpdateOne(dbName, coll,
          pp(object([<"_id", subject>])), 
          pp(object([<"$set", object([<role, target>])>])))), params)
          ];*/
}

