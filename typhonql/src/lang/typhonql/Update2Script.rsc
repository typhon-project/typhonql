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

module lang::typhonql::Update2Script

import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::Script;
import lang::typhonql::Session;
import lang::typhonql::TDBC;
import lang::typhonql::Order;
import lang::typhonql::References;
import lang::typhonql::Query2Script;
import lang::typhonql::Insert2Script;

import lang::typhonql::relational::SQL;
import lang::typhonql::relational::Util;
import lang::typhonql::relational::SQL2Text;

import lang::typhonql::mongodb::DBCollection;

import lang::typhonql::cassandra::CQL; 
import lang::typhonql::cassandra::CQL2Text; 
import lang::typhonql::cassandra::Query2CQL;
import lang::typhonql::cassandra::Schema2CQL;
import lang::typhonql::cassandra::CQLUtil;

import lang::typhonql::neo4j::Neo;
import lang::typhonql::neo4j::Neo2Text;
import lang::typhonql::neo4j::NeoUtil;

import lang::typhonql::Normalize;

import IO;
import List;
import String;
import util::Maybe;


bool isDelta((KeyVal)`<Id _> +: <Expr _>`) = true;
bool isDelta((KeyVal)`<Id _> -: <Expr _>`) = true;
default bool isDelta(KeyVal _) = false;


alias UpdateContext = tuple[
  str entity,
  Bindings myParams,
  SQLExpr sqlMe,
  DBObject mongoMe,
  NeoExpr neoMe,
  void (list[Step]) addSteps,
  void (SQLStat(SQLStat)) updateSQLUpdate,
  void (DBObject(DBObject)) updateMongoUpdate,
  void (Maybe[NeoStat](Maybe[NeoStat])) updateNeoUpdate,
  Schema schema
];


Script update2script((Request)`update <EId e> <VId x> where <{Expr ","}+ ws> set {<{KeyVal ","}* kvs>}`, Schema s) {
  str ent = "<e>";

  Place p = placeOf(ent, s);
  
  Script theScript = script([]);
  
  void addSteps(list[Step] steps) {
    theScript.steps += steps;
  }
  
  void updateStep(int idx, Step step) {
    if (idx >= size(theScript.steps)) {
      theScript.steps += [step];
    }
    else {
      theScript.steps[idx] = step;
    }
  }

  int statIndex = 0;
  
  Param toBeUpdated = field(p.name, "<x>", ent, "@id");
  str myId = newParam();
  SQLExpr sqlMe = lit(Value::placeholder(name=myId));
  DBObject mongoMe = DBObject::placeholder(name=myId);
  NeoExpr neoMe = NeoExpr::nPlaceholder(name=myId);
  CQLExpr cqlMe = cBindMarker(name=myId);
  
  Bindings myParams = ( myId: toBeUpdated );
  
  if ((Where)`where <VId _>.@id == <UUID mySelf>` := (Where)`where <{Expr ","}+ ws>`) {
    sqlMe = pointer2sql(uuid2pointer(mySelf));
    mongoMe = pointer2mongo(uuid2pointer(mySelf));
	neoMe = pointer2neo(uuid2pointer(mySelf));
	cqlMe = pointer2cql(uuid2pointer(mySelf));
    myParams = ();
  } else if ((Where)`where <VId _>.@id == <PlaceHolder mySelf>` := (Where)`where <{Expr ","}+ ws>`) {
    sqlMe = pointer2sql(placeholder2pointer(mySelf));
    mongoMe = pointer2mongo(placeholder2pointer(mySelf));
	neoMe = pointer2neo(placeholder2pointer(mySelf));
	cqlMe = pointer2cql(placeholder2pointer(mySelf));
    myParams = ();
  }
  else {
    // first, find all id's of e things that need to be updated
    Request req = (Request)`from <EId e> <VId x> select <VId x>.@id where <{Expr ","}+ ws>`;
    // NB: no partitioning, compile locally.
    addSteps(compileQuery(req, p, s));
    statIndex = size(theScript.steps);
  }
  
  
  SQLStat theUpdate = update(tableName(ent), []
    , [where([equ(column(tableName(ent), typhonId(ent)), sqlMe)])]);

  void updateSQLUpdate(SQLStat(SQLStat) block) {
    theUpdate = block(theUpdate);
    Step st = step(p.name, sql(executeStatement(p.name, pp(theUpdate))), myParams);
    updateStep(statIndex, st);
  }

  updateSQLUpdate(SQLStat(SQLStat s) { return s; });
  

  DBObject theFilter = object([<"_id", mongoMe>]);
  DBObject theObject = object([]);

  void updateMongoUpdate(DBObject(DBObject) block) {
    theObject = block(theObject);
    Step st = step(p.name, mongo(findAndUpdateOne(mongoDBName(p.name), ent, pp(theFilter), pp(theObject))), myParams);
    updateStep(statIndex, st);
  }
  
  updateMongoUpdate(DBObject(DBObject d) { return d; });
  
  Maybe[NeoStat] theNeoUpdate = Maybe::just(nMatchQuery([],[])); 
					
  void updateNeoUpdate(Maybe[NeoStat](Maybe[NeoStat]) block) {
    theNeoUpdate = block(theNeoUpdate);
    Step st = step(p.name, neo(executeNeoUpdate(p.name, neopp(theNeoUpdate.val))), myParams);
    updateStep(statIndex, st);
  }

  updateNeoUpdate(Maybe[NeoStat](Maybe[NeoStat] s) { return s; });
  
  
  UpdateContext ctx = <
    ent,
    myParams,
    sqlMe,
    mongoMe,
    neoMe,
    addSteps,
    updateSQLUpdate,
    updateMongoUpdate,
    updateNeoUpdate,
    s
  >;
  
  compileAttrSets(p, [ kv | KeyVal kv <- kvs, isAttr(kv, ent, s), !isKeyValAttr(kv, ent, s) ], ctx);
  
  lrel[str, KeyVal] keyValueDeps = 
    [ <kve, kv> | KeyVal kv <- kvs, [str _, str kve] := isKeyValAttr(ent, kv has key ? "<kv.key>" : "@id", s) ];
  
  for (str keyValEntity <- keyValueDeps<0>) {
    if (<<cassandra(), str dbName>, keyValEntity> <- s.placement) {
      list[CQLAssignment] sets = [ cSimple(cColumn(cColName(keyValEntity, "<k>")), expr2cql(e)) | (KeyVal)`<Id k>: <Expr e>` <- keyValueDeps[keyValEntity] ];
      CQLStat cqlUpdate = cUpdate(cTableName(keyValEntity)
         , sets, [cEq(CQLExpr::cColumn(cTyphonId(keyValEntity)), cqlMe)]);
      addSteps([step(dbName, cassandra(cExecuteStatement(dbName, pp(cqlUpdate))), myParams)]);
    }
    else {
      throw "Cannot find <keyValEntity> on cassandra; bug";
    }
  }
  
  for ((KeyVal)`<Id x>: <Obj obj>` <- kvs) {
   if (Rel r:<ent, Cardinality _, fromRole, str _, Cardinality _, str to, true> <- s.rels) {
      compileNestedSet(p, placeOf(to, s), ent, fromRole, r, [ obj ], ctx);
    }
  }
   

  for ((KeyVal)`<Id x>: [<{Obj ","}+ objs>]` <- kvs) {
   if (Rel r:<ent, Cardinality _, fromRole, str _, Cardinality _, str to, true> <- s.rels) {
      compileNestedSet(p, placeOf(to, s), ent, fromRole, r, [ obj | Obj obj <- objs ], ctx);
    }
  }
  
  for ((KeyVal)`<Id x> +: [<{Obj ","}+ objs>]` <- kvs) {
    if (Rel r:<ent, Cardinality _, fromRole, str _, Cardinality _, str to, true> <- s.rels) {
      compileNestedAddTo(p, placeOf(to, s), ent, fromRole, r, [ obj | Obj obj <- objs ], ctx);
    }
  }

  // TODO: make less ugly how the rel is looked up here in if-statements (also with insert)
  for ((KeyVal)`<Id x>: <Expr ref>` <- kvs, (Expr)`<Obj _>` !:= ref) {
  	maybePointer = expr2pointer(ref);
  	if (just(pointer) := maybePointer) {
    	str fromRole = "<x>"; 
    	if (Rel r:<ent, Cardinality _, fromRole, str _, Cardinality _, str to, bool _> <- s.rels) {
      		//println("COMPILING rel: <r>");
      		compileRefSet(p, placeOf(to, s), ent, fromRole, r, pointer, ctx);
    	}
    }
  }

  for ((KeyVal)`<Id x>: [<{PlaceHolderOrUUID ","}* refs>]` <- kvs) {
    str fromRole = "<x>";
    if (Rel r:<ent, Cardinality _, fromRole, str _, Cardinality _, str to, bool _> <- s.rels) {
      list[PlaceHolderOrUUID] rs = [ref| ref <- refs];
      compileRefSetMany(p, placeOf(to, s), ent, fromRole, r, refs2pointers(rs), ctx);
    }
  }

  for ((KeyVal)`<Id x> +: [<{PlaceHolderOrUUID ","}* refs>]` <- kvs) {
    str fromRole = "<x>";
    if (Rel r:<ent, Cardinality _, fromRole, str _, Cardinality _, str to, bool _> <- s.rels) {
      list[PlaceHolderOrUUID] rs = [ref| ref <- refs];
      compileRefAddTo(p, placeOf(to, s), ent, fromRole, r, refs2pointers(rs), ctx);
    }
  }

  for ((KeyVal)`<Id x> -: [<{PlaceHolderOrUUID ","}* refs>]` <- kvs) {
    str fromRole = "<x>"; 
    if (Rel r:<ent, Cardinality _, fromRole, str _, Cardinality _, str to, bool _> <- s.rels) {
      list[PlaceHolderOrUUID] rs = [ref| ref <- refs];
      compileRefRemoveFrom(p, placeOf(to, s), ent, fromRole, r, refs2pointers(rs), ctx);
    }
  }
  
  // Ugh, this is horrible.
  if (p.db is sql, theUpdate.sets == []) {
     theScript.steps = delete(theScript.steps, statIndex);
  }
  if (p.db is mongo, theObject.props == []) {
    theScript.steps = delete(theScript.steps, statIndex);
  }

  theScript.steps += [finish()];

  return theScript;
  
}
 
 
 void compileAttrSets(<sql(), str dbName>, list[KeyVal] kvs, UpdateContext ctx) {
  ctx.updateSQLUpdate(SQLStat(SQLStat upd) {
    upd.sets += [ Set::\set(columnName(kv has key ? "<kv.key>" : "@id", ctx.entity), SQLExpr::lit(evalExpr(kv.\value))) | KeyVal kv <- kvs ];
    return upd;
  });

 }
 
void compileAttrSets(<mongodb(), str dbName>, list[KeyVal] kvs, UpdateContext ctx) {
  ctx.updateMongoUpdate(DBObject(DBObject upd) {
    upd.props += [ <"$set", object([keyVal2prop(kv)])> | KeyVal kv <- kvs ];
    return upd;
  });
}

void compileAttrSets(<neo4j(), str dbName>, list[KeyVal] kvs, UpdateContext ctx) {
  ctx.updateNeoUpdate(Maybe[NeoStat](Maybe[NeoStat] upd) {
    upd.val =
       \nMatchUpdate(
  			just(nMatch
  				([nPattern(nNodePattern("__n1", [], []), [nRelationshipPattern(nDoubleArrow(), "__r1",  ctx.entity, [nProperty(typhonId(ctx.entity), ctx.neoMe)], nNodePattern("__n2", [], []))])], [])),
			nSet([nSetPlusEquals("__r1", nMapLit(( graphPropertyName(kv has key ? "<kv.key>" : "@id", ctx.entity) : nLit(evalNeoExpr(kv.\value)) | KeyVal kv <- kvs )))]),
			[nLit(nBoolean(true))]);
    return upd;
  });
}

/*
 * Nested objects in Mongo
 */
 
void compileNestedSet(<DB::mongodb(), str dbName>, <DB::mongodb(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  list[Obj] objs, UpdateContext ctx) {
  
  if (mongoDBName(dbName) != mongoDBName(other)) {
    fail;
  }
  
  if (fromCard in {one_many(), zero_many()}) {
    ctx.updateMongoUpdate(DBObject(DBObject cur) {
      cur.props += [<fromRole, array([ obj2dbObj((Expr)`<Obj obj>`) | Obj obj <- objs ])>];
      return cur;
    });
  }
  else {
    ctx.updateMongoUpdate(DBObject(DBObject cur) {
      cur.props += [<fromRole, obj2dbObj((Expr)`<Obj obj>`)> | Obj obj := objs[0] ];
      return cur;
    });
  }
}

default void compileNestedSet(Place p1, Place p2, str from, str fromRole, 
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, true>, list[Obj] objs, InsertContext ctx) {
  throw "No nested literals allowed between <p1> and <p2> for <from>-\><fromRole>-\><to>";
}
 
void compileNestedAddTo(<DB::mongodb(), str dbName>, <DB::mongodb(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  list[Obj] objs, UpdateContext ctx) {
  
  if (mongoDBName(dbName) != mongoDBName(other)) {
    fail;
  }
  
  if (fromCard in {one_many(), zero_many()}) {
    ctx.updateMongoUpdate(DBObject(DBObject cur) {
      cur.props += [<"$addToSet", object([<fromRole, 
           object([<"$each", array([ obj2dbObj((Expr)`<Obj obj>`) | Obj obj <- objs ])>])>])>];
      return cur;
    });
  }
  else {
    throw "Can only add to a array value field which <from>.<fromRole> isn\'t";
  }
 }

default void compileNestedAddTo(Place p1, Place p2, str from, str fromRole, 
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, true>, list[Obj] objs, InsertContext ctx) {
  throw "No nested literals allowed between <p1> and <p2> for <from>-\><fromRole>-\><to>";
}

/*
 * Assign to a relation, single-valued
 */

// sql/same sql containment
void compileRefSet(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  Pointer ref, UpdateContext ctx
) {
  // update ref's foreign key to point to sqlMe
  str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
  SQLStat theUpdate = update(tableName(to), [\set(fk, ctx.sqlMe)],
    [where([equ(column(tableName(to), typhonId(to)), pointer2sql(ref))])]);
  ctx.addSteps([step(dbName, sql(executeStatement(dbName, pp(theUpdate))), ctx.myParams)]);
}
 
 // sql/other sql containment
void compileRefSet(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  Pointer ref, UpdateContext ctx
) {
   // it's single ownership, so dont' insert in the junction but update.
  ctx.addSteps(updateIntoJunctionSingle(dbName, from, fromRole, to, toRole, ctx.sqlMe, pointer2sql(ref), ctx.myParams));
  ctx.addSteps(updateIntoJunctionSingle(other, to, toRole, from, fromRole, pointer2sql(ref), ctx.sqlMe, ctx.myParams));
}
 
 // sql/mongo containment
void compileRefSet(
  <DB::sql(), str dbName>, <mongodb(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  Pointer ref, UpdateContext ctx
) {
  ctx.addSteps(updateIntoJunctionSingle(dbName, from, fromRole, to, toRole, ctx.sqlMe, pointer2sql(ref), ctx.myParams));
  ctx.addSteps(updateObjectPointer(other, to, toRole, toCard, pointer2mongo(ref), ctx.mongoMe, ctx.myParams));
} 

// <str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true> 
// this is the case that the current KeyVal pair is actually
// setting the currently updated object as being owned by ref
           
// sql/same sql co-containment           
void compileRefSet(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole, 
  Rel r:<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true>,
  Pointer ref, UpdateContext ctx
) {
  // update "my" foreign key to point to uuid
  ctx.updateSQLUpdate(SQLStat(SQLStat upd) {
    str fk = fkName(parent, from, fromRole == "" ? parentRole : fromRole);
    upd.sets += [\set(fk, pointer2sql(ref))];
    return upd;
  });
}

// sql/other sql co-containment
void compileRefSet(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole, 
  Rel r:<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true>,
  Pointer ref, UpdateContext ctx
) {
  // it's single ownership, so dont' insert in the junction but update.
  ctx.addSteps(updateIntoJunctionSingle(dbName, from, fromRole, parent, parentRole, pointer2sql(ref), ctx.sqlMe, ctx.myParams));
  ctx.addSteps(updateIntoJunctionSingle(other, parent, parentRole, from, fromRole, pointer2sql(ref), ctx.sqlMe, ctx.myParams));
}

// sql/mongo containment
void compileRefSet(
  <DB::sql(), str dbName>, <DB::mongodb(), str other>, str from, str fromRole, 
  Rel r:<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true>,
  Pointer ref, UpdateContext ctx
) {
  ctx.addSteps(updateIntoJunctionSingle(dbName, from, fromRole, parent, parentRole, pointer2sql(ref), ctx.sqlMe, ctx.myParams));
  ctx.addSteps(updateObjectPointer(other, parent, parentRole, parentCard, pointer2mongo(ref), ctx.mongoMe, ctx.myParams));
}

// mongo/same mongo containment or xref
void compileRefSet(
  <DB::mongodb(), str dbName>, <DB::mongodb(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  Pointer ref, UpdateContext ctx
) {
  ctx.updateMongoUpdate(DBObject(DBObject upd) {
    upd.props += [ <"$set", object([<fromRole, pointer2mongo(ref)>])> ];
    return upd;
  });
  ctx.addSteps(updateObjectPointer(dbName, to, toRole, toCard, pointer2mongo(ref), ctx.mongoMe, ctx.myParams));
}

// mongo/other mongo containment or xref
void compileRefSet(
  <DB::mongodb(), str dbName>, <DB::mongodb(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  Pointer ref, UpdateContext ctx
) {
  ctx.updateMongoUpdate(DBObject(DBObject upd) {
    upd.props += [ <"$set", object([<fromRole, pointer2mongo(ref)>])> ];
    return upd;
  });
  ctx.addSteps(updateObjectPointer(other, to, toRole, toCard, pointer2mongo(ref), ctx.mongoMe, ctx.myParams));
}

// mongo/sql containment or xref
void compileRefSet(
  <DB::mongodb(), str dbName>, <DB::sql(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  Pointer ref, UpdateContext ctx
) {
  ctx.updateMongoUpdate(DBObject(DBObject upd) {
    upd.props +=[ <"$set", object([<fromRole, pointer2mongo(ref)>])> ];
    return upd;
  });
  
  // if the oppposite is a containment, we need to delete by kid: the original
  // owner pointer should be removed
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    ctx.addSteps(updateIntoJunctionSingleContainment(other, to, toRole, from, fromRole, pointer2sql(ref), ctx.sqlMe, ctx.myParams));
  }
  else {
    ctx.addSteps(updateIntoJunctionSingle(other, to, toRole, from, fromRole, pointer2sql(ref), ctx.sqlMe, ctx.myParams));
  }
}

// sql/same sql xref
void compileRefSet(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  Pointer ref, UpdateContext ctx
) {
  // save the cross ref
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    // inverse of containment, the target `to` owns sqlMe, so modify the update
    // to include foreign key. TODO: is this the same case as with `parent`?
    // [probably that one should be dropped]
    ctx.updateSQLUpdate(SQLStat(SQLStat upd) {
      str fk = fkName(parent, from, fromRole == "" ? parentRole : fromRole);
      upd.sets += [\set(fk, pointer2sql(ref))];
      return upd;
    });
  }
  else {
    ctx.addSteps(updateIntoJunctionSingle(dbName, from, fromRole, to, toRole, ctx.sqlMe, pointer2sql(ref), ctx.myParams));
  }
}
// sql/other sql xref
void compileRefSet(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  Pointer ref, UpdateContext ctx
) {
  ctx.addSteps(updateIntoJunctionSingle(dbName, from, fromRole, to, toRole, ctx.sqlMe, pointer2sql(ref), ctx.myParams));
  ctx.addSteps(updateIntoJunctionSingle(other, to, toRole, from, fromRole, pointer2sql(ref), ctx.sqlMe, ctx.myParams));
}

// sql/mongo xref
void compileRefSet(
  <DB::sql(), str dbName>, <DB::mongodb(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  Pointer ref, UpdateContext ctx
) {
  ctx.addSteps(updateIntoJunctionSingle(dbName, from, fromRole, to, toRole, ctx.sqlMe, pointer2sql(ref), ctx.myParams));
  ctx.addSteps(updateObjectPointer(other, to, toRole, toCard, pointer2mongo(ref), ctx.mongoMe, ctx.myParams));
}

// neo/sql containment or xref
void compileRefSet(
  <DB::neo4j(), str dbName>, <DB::sql(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  Pointer ref, UpdateContext ctx
) {
  
  ctx.addSteps(neoReplaceEnd(dbName, from, to, fromRole, 
  	ctx.neoMe, pointer2neo(ref), ctx.myParams, ctx.schema));

  /*ctx.updateMongoUpdate(DBObject(DBObject upd) {
    upd.props += [ <"$set", \value(uuid2str(ref))> ];
    return upd;
  });
  */
  
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    ctx.addSteps(updateIntoJunctionSingleContainment(other, to, toRole, from, fromRole, pointer2sql(ref), ctx.sqlMe, ctx.myParams));
  }
  else {
    ctx.addSteps(updateIntoJunctionSingle(other, to, toRole, from, fromRole, pointer2sql(ref), ctx.sqlMe, ctx.myParams));
  }
  //ctx.addSteps(updateIntoJunctionSingle(other, to, toRole, from, fromRole, pointer2sql(ref), ctx.sqlMe, ctx.myParams));
}

// neo/sql containment or xref
void compileRefSet(
  <DB::neo4j(), str dbName>, <DB::mongodb()(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  Pointer ref, UpdateContext ctx
) {
  
  ctx.addSteps(neoReplaceEnd(dbName, from, to, fromRole, 
  	ctx.neoMe, pointer2neo(ref), ctx.myParams, ctx.schema));

  ctx.addSteps(updateObjectPointer(other, to, toRole, toCard, pointer2mongo(ref), ctx.mongoMe, ctx.myParams));
}


/* 
 * Many-valued set
 */

// sql/same sql containment
void compileRefSetMany(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  list[Pointer] refs, UpdateContext ctx
) {
  // update each ref's foreign key to point to sqlMe
  str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
  SQLStat theUpdate = update(tableName(to), [\set(fk, ctx.sqlMe)],
    [where([\in(column(tableName(to), typhonId(to)), [ pointer2sql(ref) | Pointer ref <- refs ])])]);
    
  ctx.addSteps([step(dbName, sql(executeStatement(dbName, pp(theUpdate))), ctx.myParams)]);
}

// sql/other sql containment
void compileRefSetMany(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  list[Pointer] refs, UpdateContext ctx
) {
  ctx.addSteps(updateIntoJunctionMany(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
    [ pointer2sql(ref) | Pointer ref <- refs ], ctx.myParams));
  // NB: ownership is never many to many, so if fromRole is many, toRole cannot be
  ctx.addSteps([ *updateIntoJunctionSingle(other, to, toRole, from, fromRole, pointer2sql(ref), ctx.sqlMe, ctx.myParams)
    | Pointer ref <- refs ]);
}

// sql/mongo containment
void compileRefSetMany(
  <DB::sql(), str dbName>, <DB::mongodb(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  list[Pointer] refs, UpdateContext ctx
) {
  ctx.addSteps(updateIntoJunctionMany(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
     [ pointer2sql(ref) | Pointer ref <- refs ], ctx.myParams));
  
  // NB: ownership is never many to many, so if fromRole is many, toRole cannot be
  ctx.addSteps([ *updateObjectPointer(other, to, toRole, toCard, pointer2mongo(ref), ctx.mongoMe, ctx.myParams) 
      | Pointer ref <- refs ]);

 // we need to delete all Mongo objects in role that have a ref to mongome via toRole
 // whose _id is not in refs.
  DBObject q = object([<"_id", object([<"$nin", array([ pointer2mongo(ref) | Pointer ref <- refs ])>])>
     , <toRole, ctx.mongoMe>]);
  ctx.addSteps([ step(other, mongo(deleteMany(mongoDBName(other), to, pp(q))), ctx.myParams)]);
}

// sql/same sql xref
void compileRefSetMany(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  list[Pointer] refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(updateIntoJunctionMany(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
    [ pointer2sql(ref) | Pointer ref <- refs ], ctx.myParams));
}

// sql/other sql xref
void compileRefSetMany(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  list[Pointer] refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(updateIntoJunctionMany(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
    [ pointer2sql(ref) | Pointer ref <- refs ], ctx.myParams));
  ctx.addSteps([ *updateIntoJunctionSingle(other, to, toRole, from, fromRole, pointer2sql(ref), ctx.sqlMe, ctx.myParams)
                 | Pointer ref <- refs ]);
}

// sql/mongo xref
void compileRefSetMany(
  <DB::sql(), str dbName>, <DB::mongodb(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  list[Pointer] refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  // todo: deal with multiplicity correctly in updateObject Pointer
  ctx.addSteps([ *updateObjectPointer(other, to, toRole, toCard, pointer2mongo(ref), ctx.mongoMe, ctx.myParams) 
      | Pointer ref <- refs ]);
}

// mongo/same mongo containment or xref
void compileRefSetMany(
  <DB::mongodb(), str dbName>, <DB::mongodb(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  list[Pointer] refs, UpdateContext ctx
) {
  ctx.updateMongoUpdate(DBObject(DBObject upd) {
    upd.props += [ <"$set", object([<fromRole, array([ pointer2mongo(ref) | Pointer ref <- refs ])>])> ];
    return upd;
  });
  ctx.addSteps([ *updateObjectPointer(dbName, to, toRole, toCard, pointer2mongo(ref), ctx.mongoMe, ctx.myParams)
                | Pointer ref <- refs ]);
                
  // we need to update all Mongo objects that have a pointer to mongoMe via toRole
  // whose _id is not in refs, and in case of containment, delete them [do we have containment that is not native in Mongo?]
  
  DBObject q = object([<"_id", object([<"$nin", array([ pointer2mongo(ref) | Pointer ref <- refs ])>])>, <toRole, ctx.mongoMe>]);
  DBObject u = object([<"$set", object([<toRole, DBObject::null()>])>]); 
  if (toCard in {zero_many(), one_many()}) { 
    u = object([<"$pull", 
               object([<toRole, 
                 object([<"$in", array([ ctx.mongoMe ])>])>])>]);
  }              
  ctx.addSteps([ step(dbName, mongo(findAndUpdateMany(mongoDBName(dbName), to, pp(q), pp(u))), ctx.myParams)]); 
}

// mongo/other mongo containment or xref
void compileRefSetMany(
  <DB::mongodb(), str dbName>, <DB::mongodb(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  list[Pointer] refs, UpdateContext ctx
) {
  ctx.updateMongoUpdate(DBObject(DBObject upd) {
    upd.props += [ <"$set", object([<fromRole, array([ pointer2mongo(ref) | Pointer ref <- refs ])>])> ];
    return upd;
  });
  ctx.addSteps([ *updateObjectPointer(other, to, toRole, toCard, pointer2mongo(ref), ctx.mongoMe, ctx.myParams)
                | Pointer ref <- refs ]);

  // we need to update all Mongo objects that have a pointer to mongoMe via toRole
  // whose _id is not in refs, and in case of containment, delete them [do we have containment that is not native in Mongo?]
  
  DBObject q = object([<"_id", object([<"$nin", array([ pointer2mongo(ref) | Pointer ref <- refs ])>])>, <toRole, ctx.mongoMe>]);
  DBObject u = object([<"$set", object([<toRole, DBObject::null()>])>]); 
  if (toCard in {zero_many(), one_many()}) { 
    u = object([<"$pull", 
               object([<toRole, 
                 object([<"$in", array([ ctx.mongoMe ])>])>])>]);
  }              
  ctx.addSteps([ step(other, mongo(findAndUpdateMany(mongoDBName(dbName), to, pp(q), pp(u))), ctx.myParams)]);              
}

// mongo/sql containment or xref
void compileRefSetMany(
  <DB::mongodb(), str dbName>, <DB::mongodb(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  list[Pointer] refs, UpdateContext ctx
) {
  ctx.updateMongoUpdate(DBObject(DBObject upd) {
    upd.props += [ <"$set", object([<fromRole, array([ pointer2mongo(ref) | Pointer ref <- refs ])>])> ];
    return upd;
  });
  ctx.addSteps([ *updateIntoJunctionSingle(other, to, toRole, from, fromRole, pointer2sql(ref), ctx.sqlMe, ctx.myParams)
                | Pointer ref <- refs ]);
}


/*
 * Adding to many-valued collections
 */
 
// sql/same sql containment 
void compileRefAddTo(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  list[Pointer] refs, UpdateContext ctx
) {
  // update each ref's foreign key to point to sqlMe
  str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
  SQLStat theUpdate = update(tableName(to), [\set(fk, ctx.sqlMe)],
    [where([\in(column(tableName(to), typhonId(to)), [ pointer2sql(ref) | Pointer ref <- refs ])])]);
    
  ctx.addSteps([step(dbName, sql(executeStatement(dbName, pp(theUpdate))), ctx.myParams)]);
}  

// sql/other sql containment
void compileRefAddTo(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  list[Pointer] refs, UpdateContext ctx
) {
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
     [ pointer2sql(ref) | Pointer ref <- refs ], ctx.myParams));
  // NB: ownership is never many to many, so if fromRole is many, toRole cannot be
  ctx.addSteps([ *updateIntoJunctionSingle(other, to, toRole, from, fromRole, pointer2sql(ref), ctx.sqlMe, ctx.myParams)
    | Pointer ref <- refs ]);
}

// sql/mongo containment
void compileRefAddTo(
  <DB::sql(), str dbName>, <DB::mongodb(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  list[Pointer] refs, UpdateContext ctx
) {
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
    [ pointer2sql(ref) | Pointer ref <- refs ], ctx.myParams));
  
  // NB: ownership is never many to many, so if fromRole is many, toRole cannot be
  ctx.addSteps([ *updateObjectPointer(other, to, toRole, toCard, pointer2mongo(ref), ctx.mongoMe, ctx.myParams) 
      | Pointer ref <- refs ]);
}

// sql/same sql xref 
void compileRefAddTo(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  list[Pointer] refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  // save the cross ref
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [ pointer2sql(ref) | Pointer ref <- refs ], ctx.myParams));
}
  
// sql/other sql xref
void compileRefAddTo(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  list[Pointer] refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [ pointer2sql(ref) | Pointer ref <- refs ], ctx.myParams));
  ctx.addSteps([ *insertIntoJunctionSingle(other, to, toRole, from, fromRole, pointer2sql(ref), ctx.sqlMe, ctx.myParams)
                 | Pointer ref <- refs ]);
}

// sql/mongo xref
void compileRefAddTo(
  <DB::sql(), str dbName>, <DB::mongodb(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  list[Pointer] refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [ pointer2sql(ref) | Pointer ref <- refs ], ctx.myParams));
  // todo: deal with multiplicity correctly in updateObject Pointer
  ctx.addSteps([ *updateObjectPointer(other, to, toRole, toCard, pointer2mongo(ref), ctx.mongoMe, ctx.myParams) 
      | Pointer ref <- refs ]);
}

// mongo/same mongo containment or xref
void compileRefAddTo(
  <DB::mongodb(), str dbName>, <DB::mongodb(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  list[Pointer] refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.updateMongoUpdate(DBObject(DBObject upd) {
    //upd.props += [ <"$set", object([<fromRole, array([ pointer2mongo(ref) | Pointer ref <- refs ])>])> ];
    upd.props +=  [<"$addToSet", object([<fromRole, object([<"$each", array([ pointer2mongo(ref) | Pointer ref <- refs ])>])>])>];
    return upd;
  });
  
  //ctx.addSteps(insertObjectPointers(dbName, from, fromRole, fromCard, ctx.mongoMe, 
  //           [ pointer2mongo(ref) | Pointer ref <- refs ], ctx.myParams));
  ctx.addSteps([ *insertObjectPointer(dbName, to, toRole, toCard, pointer2mongo(ref) , ctx.mongoMe, ctx.myParams)
                | Pointer ref <- refs ]);
}

// mongo/other mongo containment or xref
void compileRefAddTo(
  <DB::mongodb(), str dbName>, <DB::mongodb(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  list[Pointer] refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.updateMongoUpdate(DBObject(DBObject upd) {
    //upd.props += [ <"$set", object([<fromRole, array([ pointer2mongo(ref) | Pointer ref <- refs ])>])> ];
    upd.props +=  [<"$addToSet", object([<fromRole, object([<"$each", array([ pointer2mongo(ref) | Pointer ref <- refs ])>])>])>];
    return upd;
  });
  
  //ctx.addSteps(insertObjectPointers(dbName, from, fromRole, fromCard, ctx.mongoMe, 
  //           [ pointer2mongo(ref) | Pointer ref <- refs ], ctx.myParams));
  ctx.addSteps([ *insertObjectPointer(dbName, to, toRole, toCard, pointer2mongo(ref) , ctx.mongoMe, ctx.myParams)
                | Pointer ref <- refs ]);
}

// mongo/sql containment or xref
void compileRefAddTo(
  <DB::mongodb(), str dbName>, <DB::sql(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  list[Pointer] refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.updateMongoUpdate(DBObject(DBObject upd) {
    //upd.props += [ <"$set", object([<fromRole, array([ pointer2mongo(ref) | Pointer ref <- refs ])>])> ];
    upd.props +=  [<"$addToSet", object([<fromRole, object([<"$each", array([ pointer2mongo(ref) | Pointer ref <- refs ])>])>])>];
    return upd;
  });
  //ctx.addSteps(insertObjectPointers(dbName, from, fromRole, fromCard, ctx.mongoMe, 
  //           [ pointer2mongo(ref) | Pointer ref <- refs ], ctx.myParams));
  ctx.addSteps([ *updateIntoJunctionSingle(other, to, toRole, from, fromRole, pointer2sql(ref), ctx.sqlMe, ctx.myParams)
                | Pointer ref <- refs ]);
}



/*
 * Removing from many-valued refs 
 */
 
 // sql/same sql containment
void compileRefRemoveFrom(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  list[Pointer] refs, UpdateContext ctx
) {
  // delete each ref (we cannot orphan them)
  str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
  SQLStat theUpdate = delete(tableName(to), 
    [where([\in(column(tableName(to), typhonId(to)), [ pointer2sql(ref) | Pointer ref <- refs ])])]);
    
  ctx.addSteps([step(dbName, sql(executeStatement(dbName, pp(theUpdate))), ctx.myParams)]);
}

// sql/other sql containment
void compileRefRemoveFrom(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  list[Pointer] refs, UpdateContext ctx
) {
  ctx.addSteps(removeFromJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
    [ pointer2sql(ref) | Pointer ref <- refs ], ctx.myParams));
    
  // NB: ownership is never many to many, so if fromRole is many, toRole cannot be
  ctx.addSteps([ *removeFromJunction(other, to, toRole, from, fromRole, pointer2sql(ref), ctx.sqlMe, ctx.myParams)
    | Pointer ref <- refs]);     
  ctx.addSteps(deleteManySQL(other, to, [ pointer2sql(ref) | Pointer ref <- refs ]));
}

// sql/mongo containment
void compileRefRemoveFrom(
  <DB::sql(), str dbName>, <DB::mongodb(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  list[Pointer] refs, UpdateContext ctx
) {
  ctx.addSteps(removeFromJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
    [ pointer2sql(ref) | Pointer ref <- refs ], ctx.myParams));
    
  ctx.addSteps(deleteManyMongo(other, to, [ pointer2mongo(ref) | Pointer ref <- refs ], ctx.myParams));
}

// sql/same sql xref 
void compileRefRemoveFrom(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  list[Pointer] refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(removeFromJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [ pointer2sql(ref) | Pointer ref <- refs ], ctx.myParams));
}

// sql/other sql xref
void compileRefRemoveFrom(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  list[Pointer] refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(removeFromJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [ pointer2sql(ref) | Pointer ref <- refs ], ctx.myParams));
  ctx.addSteps([ removeJunction(other, to, toRole, from, fromRole, pointer2sql(ref), ctx.sqlMe, ctx.myParams)
                 | Pointer ref <- refs ]);
}

// sql/mongo xref
void compileRefRemoveFrom(
  <DB::sql(), str dbName>, <DB::mongodb(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  list[Pointer] refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(removeFromJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [ pointer2sql(ref) | Pointer ref <- refs ], ctx.myParams));
  ctx.addSteps(deleteManyMongo(other, to, [ pointer2mongo(ref) | Pointer ref <- refs ], ctx.myParams));
  
}

// mongo/same mongo containment or xref
void compileRefRemoveFrom(
  <DB::mongodb(), str dbName>, <DB::mongodb(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  list[Pointer] refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(removeObjectPointers(dbName, from, fromRole, fromCard, ctx.mongoMe, 
             [ pointer2mongo(ref) | Pointer ref <- refs ], ctx.myParams));  
  ctx.addSteps([*removeObjectPointers(dbName, to, toRole, toCard, pointer2mongo(ref), [ctx.mongoMe], ctx.myParams)
                | Pointer ref <- refs ]);
}

// mongo/other mongo containment or xref
void compileRefRemoveFrom(
  <DB::mongodb(), str dbName>, <DB::mongodb(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  list[Pointer] refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(removeObjectPointers(dbName, from, fromRole, fromCard, ctx.mongoMe, 
             [ pointer2mongo(ref) | Pointer ref <- refs ], ctx.myParams));  
  ctx.addSteps([*removeObjectPointers(other, to, toRole, toCard, pointer2mongo(ref), [ctx.mongoMe], ctx.myParams)
                | Pointer ref <- refs ]);
}

// mongo/sql containment or xref
void compileRefRemoveFrom(
  <DB::mongodb(), str dbName>, <DB::sql(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  list[Pointer] refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(removeObjectPointers(dbName, from, fromRole, fromCard, ctx.mongoMe, 
             [ pointer2mongo(ref) | Pointer ref <- refs ], ctx.myParams));  
  ctx.addSteps([*removeFromJunction(other, from, fromRole, to, toRole, pointer2sql(ref), [ctx.sqlMe], ctx.myParams) 
                  | Pointer ref <- refs ]);
}
