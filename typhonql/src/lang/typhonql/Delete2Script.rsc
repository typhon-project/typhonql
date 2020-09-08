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

module lang::typhonql::Delete2Script


import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::Script;
import lang::typhonql::Session;
import lang::typhonql::TDBC;
import lang::typhonql::Order;
import lang::typhonql::Normalize;

import lang::typhonql::Insert2Script;
//import lang::typhonql::Update2Script;
import lang::typhonql::References;
import lang::typhonql::Query2Script;



import lang::typhonql::relational::SQL;
import lang::typhonql::relational::Util;
import lang::typhonql::relational::SQL2Text;
import lang::typhonql::relational::Query2SQL;

import lang::typhonql::mongodb::Query2Mongo;
import lang::typhonql::mongodb::DBCollection;

import lang::typhonql::cassandra::CQL; 
import lang::typhonql::cassandra::CQL2Text; 
import lang::typhonql::cassandra::Query2CQL;
import lang::typhonql::cassandra::Schema2CQL;
import lang::typhonql::cassandra::CQLUtil;

import lang::typhonql::neo4j::Neo;
import lang::typhonql::neo4j::Neo2Text;
import lang::typhonql::neo4j::NeoUtil;


import IO;
import List;
import Map;
import Set;
import util::Maybe;

alias DeleteContext = tuple[
  str entity,
  Bindings myParams,
  Bindings nextStepParams,
  Expr me,
  SQLExpr sqlMe,
  DBObject mongoMe,
  CQLExpr cqlMe,
  NeoExpr neoMe,
  void (list[Step]) addSteps,
  Schema schema
];

Script delete2script((Request)`delete <EId e> <VId x> where <{Expr ","}+ ws>`, Schema s,
	Bindings initialParams = (), bool secondTime = false) {
  //s.rels = symmetricReduction(s.rels);
  
  str ent = "<e>";
  Place p = placeOf(ent, s);

  Param toBeDeleted = field(p.name, "<x>", ent, "@id");
  str myId = newParam();
  Expr me = [Expr] "??<myId>";
  SQLExpr sqlMe = lit(Value::placeholder(name=myId));
  DBObject mongoMe = DBObject::placeholder(name=myId);
  CQLExpr cqlMe = cBindMarker(name=myId);
  NeoExpr neoMe = NeoExpr::nPlaceholder(name=myId);
  Bindings myParams = isEmpty(initialParams)?( myId: toBeDeleted ):initialParams;
  Bindings nextStepParams = ();
  Script theScript = script([]);
  
  void addSteps(list[Step] steps) {
    theScript.steps += steps;
  }
  
  if ((Where)`where <VId _>.@id == <UUID mySelf>` := (Where)`where <{Expr ","}+ ws>`) {
    me = (Expr) `<UUID mySelf>`;
    sqlMe = pointer2sql(uuid2pointer(mySelf));
    mongoMe = pointer2mongo(uuid2pointer(mySelf));
	neoMe = pointer2neo(uuid2pointer(mySelf));
	cqlMe = pointer2cql(uuid2pointer(mySelf));
    myParams = ();
  } else if ((Where)`where <VId _>.@id == <PlaceHolder mySelf>` := (Where)`where <{Expr ","}+ ws>`) {
  	me = (Expr) `<PlaceHolder mySelf>`;
    sqlMe = pointer2sql(placeholder2pointer(mySelf));
    mongoMe = pointer2mongo(placeholder2pointer(mySelf));
	neoMe = pointer2neo(placeholder2pointer(mySelf));
	cqlMe = pointer2cql(placeholder2pointer(mySelf));
    myParams = ();
  }
  else {
    // first, find all id's of e things that need to be updated
    Request req = (Request)`from <EId e> <VId x> select <VId x>.@id where <{Expr ","}+ ws>`;
    querySteps = compileQuery(req, p, s, initialParams = initialParams);
    addSteps(querySteps);
    nextStepParams = (myId: field(p.name, "<x>", "<e>", "@id"));
    myParams = () + nextStepParams;
  }
  
  
  
  DeleteContext ctx = <
    ent,
    myParams,
    nextStepParams,
    me,
    sqlMe,
    mongoMe,
    cqlMe,
    neoMe,
    addSteps,
    s
  >;
 
  for (Rel r:<ent, Cardinality _, _, _, _, str to, true> <- s.rels) {
     //println("Deleting kids: <ent> -\> <to>");
     deleteKids(p, placeOf(to, s), r, ctx);
  }
  
  for (Rel r:<str ref, _, _, _, _, ent, _> <- s.rels) {
     // NB: r is not in the direction of p and placeOf(ref, s)
     //println("Deleting inbound: <ref> -\> <ent>");
     breakInboundPointers(p, placeOf(ref, s), r, ctx);
  }

  for (Rel r:<ent, _, _, _, _, str to, false> <- s.rels) {
     //println("Outbound: <ent> -\> <to>");
     breakOutboundPointers(p, placeOf(to, s), r, ctx, secondTime = secondTime);
  }

  
  deleteObject(p, ctx);
  
  deleteReferenceInNeo(ctx);
  
  theScript.steps += [finish()];
  
  return theScript;
  
}

void deleteObject(<sql(), str dbName>, DeleteContext ctx) {
  SQLStat stat = delete(tableName(ctx.entity),
      [where([equ(column(tableName(ctx.entity), typhonId(ctx.entity)), ctx.sqlMe)])]);
      
  ctx.addSteps([step(dbName, sql(executeStatement(dbName, pp(stat))), ctx.myParams)]); 
}

void deleteObject(<mongodb(), str dbName>, DeleteContext ctx) {
  ctx.addSteps([ step(dbName, mongo(deleteOne(dbName, ctx.entity, pp(object([<"_id", ctx.mongoMe>])))), ctx.myParams) ]);
}

void deleteObject(<neo4j(), str dbName>, DeleteContext ctx) {
	ctx.addSteps(deleteNeoObject(dbName, ctx.entity, ctx.neoMe, ctx.myParams, ctx));
}

list[Step] deleteNeoObject(str dbName, str entity, NeoExpr neoMe, Bindings params, DeleteContext ctx) {
 NeoStat stat = 
 	\nMatchUpdate(Maybe::just(nMatch([nPattern(nNodePattern("__n1", [], []), 
 			[nRelationshipPattern(nDoubleArrow(), "__r1", entity, [ nProperty(typhonId(entity), neoMe) ], nNodePattern("n__2", [], []))])], [])), 
 		nDelete([nVariable("__r1")]),
 		[nLit(nBoolean(true))]);
 
  //removeEdgeAssociations(dbName, entity, ctx);
  return [ step(dbName, neo(executeNeoUpdate(dbName, neopp(stat))), params) ];
}

/*
 * Remove reference in Neo
 */
void deleteReferenceInNeo(DeleteContext ctx) {
	ctx.addSteps(deleteReferenceInNeo(ctx.entity, ctx.neoMe, ctx.myParams, ctx.schema));
	
} 
 
list[Step] deleteReferenceInNeo(str theEntity, NeoExpr neoMe, Bindings params, Schema sch) {
	steps = [];
	for (<<neo4j(), db>, e> <- sch.placement) {
		if (<e, _, _, _, _, entity, _> <- sch.rels, entity == theEntity) {
			str deleteStmt = neopp(
				\nMatchUpdate(
					just(nMatch(
							[nPattern(nNodePattern("__n1", [theEntity], [nProperty(typhonId(theEntity), neoMe)]), [])],
							[]
					)),
					nDetachDelete([nVariable("__n1")]),
					[nLit(nBoolean(true))]));
			steps += [step(db, neo(executeNeoUpdate(db, deleteStmt)), params)];
		} 
	}
	return steps;
}

/*
 * Cascade to owned objects
 */

void deleteKids(
  <sql(), str dbName>, <sql(), dbName>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>, 
  DeleteContext ctx
) {
  // automatic through cascade delete clauses
}


void deleteKids(
  <sql(), str dbName>, <sql(), str other:!dbName>,
  <str from, Cardinality fromCard, str fromRole, str toRole, Cardinality toCard, str to, true>, 
  DeleteContext ctx
) {
  ctx.addSteps(removeFromJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, ctx.myParams));
  ctx.addSteps(cascadeViaJunction(other, to, toRole, from, fromRole, ctx.sqlMe, ctx.myParams));
}

void deleteKids(
  <sql(), str dbName>, <mongodb(), str other>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>, 
  DeleteContext ctx
) {
  ctx.addSteps(removeFromJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, ctx.myParams));
  ctx.addSteps(cascadeViaInverse(other, to, toRole, ctx.mongoMe, ctx.myParams));   
}


void deleteKids(
  <mongodb(), str dbName>, <mongodb(), dbName>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>, 
  DeleteContext ctx
) {
  // immediate because of nesting
}


void deleteKids(
  <mongodb(), str dbName>, <sql(), str other>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>, 
  DeleteContext ctx
) {
  // cascadeViaJunction deletes from "to" and from the (inverse) junction table modeling
  // this containment relation
  ctx.addSteps(cascadeViaJunction(other, to, toRole, from, fromRole, ctx.sqlMe, ctx.myParams));  
}

tuple[str,str] getFromTo(str entity, Schema s) {
	if  (<dbName, graphSpec({ _*, <entity, from, to> , _*})> <- s.pragmas)
		return <from, to>;
	else
		throw "Not from/to relations declared"; 
}

str getOppositeEnd(str entity, str r, Schema s) {
	<from, to> = getFromTo(entity, s);
	return (from==r)?to:from;
}

void deleteKids(
  <sql(), str dbName>, <neo4j(), str other>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>, 
  DeleteContext ctx
) {
  ctx.addSteps(removeFromJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, ctx.myParams));
  
  ctx.addSteps(cascadeViaInverseNeo(other, to, toRole, from, ctx.neoMe, ctx.myParams, ctx.schema));
  
  Request removeEdge = [Request] "delete <to> edge where edge.<toRole> == <ctx.me>";
  Script scr = delete2script(removeEdge, ctx.schema);
  ctx.addSteps(scr.steps);
  
  //deleteObject(<neo4j(), other>, ctx);
  //deleteReferenceInNeo(to, ctx.neoMe, ctx.myParams, ctx.schema);
}

/*
 * KeyValueDBs only have incoming ownership pointers
 */

void deleteKids(
  <sql(), str dbName>, <cassandra(), str other>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>, 
  DeleteContext ctx
) {
  CQLStat stmt = cDelete(cTableName(to), [cEq(CQLExpr::cColumn(cTyphonId(to)), ctx.cqlMe)]);
  ctx.addSteps([step(other, cassandra(cExecuteStatement(other, pp(stmt))), ctx.myParams)]);  
}

void deleteKids(
  <mongodb(), str dbName>, <cassandra(), str other>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>, 
  DeleteContext ctx
) {
  CQLStat stmt = cDelete(cTableName(to), [cEq(CQLExpr::cColumn(cTyphonId(to)), ctx.cqlMe)]);
  ctx.addSteps([step(other, cassandra(cExecuteStatement(other, pp(stmt))), ctx.myParams)]);  
}

void deleteKids(
  <mongodb(), str dbName>, <neo4j(), str other>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>, 
  DeleteContext ctx
) {
  Request removeEdge = [Request] "delete <to> edge where edge.<toRole> == <ctx.me>";
  Script scr = delete2script(removeEdge, ctx.schema);
  ctx.addSteps(scr.steps);
  //deleteObject(<neo4j(), other>, ctx);
  //deleteReferenceInNeo(to, ctx.neoMe, ctx.myParams, ctx.schema);
}


/*
 * Break pointers into the deleted objects
 */
 
 
void breakInboundPointers(
  del:<sql(), str dbName>, incoming:<sql(), dbName>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str deleted, bool contain>, 
  DeleteContext ctx
) {
  if (contain) {
    // do nothing because the containment is modeled using a foreign key on 
    // the deleted child, so the link is broken automatically.
    return;
  }

  // and also here nothing needs to be done
  // because the junction tables have cascade delete
  // on the tables they point to; deleting the kid
  // will delete the entry as well.
}
 

void breakInboundPointers(
  del:<sql(), str dbName>, incoming:<sql(), str other:!dbName>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str deleted, bool contain>, 
  DeleteContext ctx
) {
  // local junction tables are updated because of cascade delete
  
  ctx.addSteps(removeFromJunction(other, from, fromRole, deleted, toRole, ctx.sqlMe, ctx.myParams));
}

void breakInboundPointers(
  del:<sql(), str dbName>, incoming:<mongodb(), str other>,
  <str from, Cardinality fromCard, str fromRole, str toRole, Cardinality toCard, str deleted, bool contain>, 
  DeleteContext ctx
) {
  // local junction tables are updated because of cascade delete
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    ;
    // it has been deleted via deleteKids
  }
  else {
    ctx.addSteps(removeAllObjectPointers(other, from, fromRole, fromCard, ctx.mongoMe, ctx.myParams));
  }
}


void breakInboundPointers(
  del:<mongodb(), str dbName>, incoming:<mongodb(), dbName>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str deleted, bool contain>, 
  DeleteContext ctx
) {
  ctx.addSteps(removeAllObjectPointers(dbName, from, fromRole, fromCard, ctx.mongoMe, ctx.myParams));
}

void breakInboundPointers(
  del:<mongodb(), str dbName>, incoming:<mongodb(), str other:!dbName>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str deleted, bool contain>, 
  DeleteContext ctx
) {
  ctx.addSteps(removeAllObjectPointers(other, from, fromRole, fromCard, ctx.mongoMe, ctx.myParams));
}

void breakInboundPointers(
  del:<mongodb(), str dbName>, incoming:<sql(), str other>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str deleted, bool contain>, 
  DeleteContext ctx
) {
  ctx.addSteps(removeFromJunction(other, from, fromRole, deleted, toRole, ctx.sqlMe, ctx.myParams));
}

void breakInboundPointers(
  del:<neo4j(), str dbName>, incoming:<sql(), str other>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str deleted, bool contain>, 
  DeleteContext ctx
) {
  ctx.addSteps(removeFromJunction(other, from, fromRole, deleted, toRole, ctx.sqlMe, ctx.myParams));
}

void breakInboundPointers(
  del:<neo4j(), str dbName>, incoming:<mongodb(), str other>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str deleted, bool contain>, 
  DeleteContext ctx
) {

  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    ;
    // it has been deleted via deleteKids
  }
  else {
    ctx.addSteps(removeAllObjectPointers(other, from, fromRole, fromCard, ctx.mongoMe, ctx.myParams));
  }
}

void breakInboundPointers(
  del:<sql(), str dbName>, incoming:<neo4j(), str other>,
  <str from, Cardinality fromCard, str fromRole, str toRole, Cardinality toCard, str deleted, bool contain>, 
  DeleteContext ctx
) {
  // local junction tables are updated because of cascade delete
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    ;
    // it has been deleted via deleteKids
  }
  else {
  	;
    // Not necessary in the case of neo
    //ctx.addSteps(removeAllObjectPointers(other, from, fromRole, fromCard, ctx.mongoMe, ctx.myParams));
  }
}

/*
 * Break cross-ref pointers out of the deleted objects
 */
 
 void breakOutboundPointers(
  del:<sql(), str dbName>, <sql(), dbName>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>, 
  DeleteContext ctx, bool secondTime = false
) {
  // automatic because of foreign keys from junction table to from
}
 

 void breakOutboundPointers(
  del:<sql(), str dbName>, <sql(), str other:!dbName>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>, 
  DeleteContext ctx, bool secondTime = false
) {
  // automatic because of foreign keys from junction table to from on this db
  
  // but not for the inverse on other:
  //ctx.addSteps(removeFromJunction(other, from, fromRole, to, toRole, ctx.sqlMe, ctx.myParams));
}


void breakOutboundPointers(
  del:<sql(), str dbName>, <mongodb(), str other>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>, 
  DeleteContext ctx, bool secondTime = false
) {
  // automatic because of foreign keys from junction table to from on this db
  
  // but not for the inverse on other:
   ctx.addSteps(removeAllObjectPointers(other, to, toRole, toCard, ctx.mongoMe, ctx.myParams));
}


void breakOutboundPointers(
  del:<mongodb(), str dbName>, <mongodb(), dbName>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>, 
  DeleteContext ctx, bool secondTime = false
) {
  // automatic because of deletion of object in the from db
  
  // but not for the inverse 
  ctx.addSteps(removeAllObjectPointers(dbName, to, toRole, toCard, ctx.mongoMe, ctx.myParams));
}
 
void breakOutboundPointers(
  del:<mongodb(), str dbName>, <mongodb(), str other:!dbName>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>, 
  DeleteContext ctx, bool secondTime = false
) {
  // automatic because of deletion of object in the from db
  
  // but not for the inverse on other
  ctx.addSteps(removeAllObjectPointers(other, to, toRole, toCard, ctx.mongoMe, ctx.myParams));
}

void breakOutboundPointers(
  del:<mongodb(), str dbName>, <sql(), str other>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>, 
  DeleteContext ctx, bool secondTime = false
) {
  // automatic because of deletion of object in the from db
  
  // but not for the inverse on sql
  ctx.addSteps(removeFromJunction(other, from, fromRole, to, toRole, ctx.sqlMe, ctx.myParams));
}

void breakOutboundPointers(
  del:<neo4j(), str dbName>, <sql(), str other>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>, 
  DeleteContext ctx, bool secondTime = false
) {
  // automatic because of deletion of object in the from db
  
  // but not for the inverse on sql
  //if (!secondTime)
  ctx.addSteps(removeFromJunction(other, from, fromRole, to, toRole, ctx.sqlMe, ctx.myParams));
} 

void breakOutboundPointers(
  del:<neo4j(), str dbName>, <mongodb(), str other>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>, 
  DeleteContext ctx
) {
  // automatic because of foreign keys from junction table to from on this db
  
  // but not for the inverse on other:
   ctx.addSteps(removeAllObjectPointers(other, to, toRole, toCard, ctx.mongoMe, ctx.myParams));
}

 
  
  
