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

module lang::typhonql::Insert2Script

import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::Script;
import lang::typhonql::util::Strings;
import lang::typhonql::util::Dates;
import lang::typhonql::Normalize;
import lang::typhonql::Session;
import lang::typhonql::TDBC;
import lang::typhonql::Order;
import lang::typhonql::References;

import lang::typhonql::relational::SQL;
import lang::typhonql::relational::Util;
import lang::typhonql::relational::SQL2Text;

import lang::typhonql::mongodb::DBCollection;

import lang::typhonql::cassandra::CQL; 
import lang::typhonql::cassandra::CQL2Text; 
import lang::typhonql::cassandra::Query2CQL;
import lang::typhonql::cassandra::Schema2CQL;

import lang::typhonql::neo4j::Neo;
import lang::typhonql::neo4j::Neo2Text;
import lang::typhonql::neo4j::NeoUtil;

import lang::typhonql::nlp::Nlp;

import IO;
import ValueIO;
import List;
import String;
import util::Maybe;

bool hasId({KeyVal ","}* kvs) = hasId([ kv | KeyVal kv <- kvs ]);

bool hasId(list[KeyVal] kvs) = any((KeyVal)`@id: <Expr _>` <- kvs);

str evalId({KeyVal ","}* kvs) = "<e>"[1..]
  when (KeyVal)`@id: <UUID e>` <- kvs;

alias InsertContext = tuple[
  str entity,
  Bindings myParams,
  SQLExpr sqlMe,
  DBObject mongoMe,
  CQLExpr cqlMe,
  NeoExpr neoMe,
  void (list[Step]) addSteps,
  void (SQLStat(SQLStat)) updateSQLInsert,
  void (DBObject(DBObject)) updateMongoInsert,
  void (NeoStat(NeoStat)) updateNeoInsert,
  Schema schema
];

/*

Insert with key value things:
first insert the keyvalue props, with
primary key SQL/Mongo me

Then insert the rest.

*/

Script insert2script((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, Schema s) {
  str entity = "<e>";
  Place p = placeOf(entity, s);
  str myId = newParam();
  Bindings myParams = ( myId: generatedId(myId) | !hasId(kvs) );
  NlpId nlpMe = hasId(kvs) ? NlpId::id(evalId(kvs)) : NlpId::placeholder(myId);
  SQLExpr sqlMe = hasId(kvs) ? lit(sUuid(evalId(kvs))) : SQLExpr::placeholder(name=myId);
  DBObject mongoMe = hasId(kvs) ? mUuid(evalId(kvs)) : DBObject::placeholder(name=myId);
  CQLExpr cqlMe = hasId(kvs) ? cTerm(cUUID(evalId(kvs))) : cBindMarker(name=myId);
  NeoExpr neoMe = hasId(kvs) ? nLit(nText(evalId(kvs))) : NeoExpr::nPlaceholder(name=myId);

  SQLStat theInsert = \insert(tableName("<e>"), [], []);
  DBObject theObject = object([ ]);
  NeoStat theCreate = \nMatchUpdate(Maybe::just(nMatch([], [])), nCreate(nPattern(nNodePattern("n", [], []), [nRelationshipPattern(nDoubleArrow(), "", "", [], nNodePattern("", [], []))])), [nLit(nBoolean(true))]);

  Script theScript = script([]);
  
  void addSteps(list[Step] steps) {
    //println("Adding steps:");
    //for (Step st <- steps) {
    //  println(" - <st>");
    //}
    theScript.steps += steps;
  }
  
  
  
  void updateStep(int idx, Step s) {
    if (idx >= size(theScript.steps)) {
      theScript.steps += [s];
    }
    else {
      theScript.steps[idx] = s;
    }
  }
  
  void updateSQLInsert(SQLStat(SQLStat) block) {
    int idx = hasId(kvs) ? 0 : 1;
    //println("Updating the insert statement:");
    //println("- Was: <theInsert>");
    theInsert = block(theInsert);
    //println("- Became: <theInsert>");
    updateStep(idx, step(p.name, sql(executeStatement(p.name, pp(theInsert))), myParams));
  }
  
  void updateMongoInsert(DBObject(DBObject) block) {
    int idx = hasId(kvs) ? 0 : 1;
    theObject = block(theObject);
    updateStep(idx, step(p.name, mongo(insertOne(p.name, "<e>", pp(theObject))), myParams));
  }
 
  void updateNeoInsert(NeoStat(NeoStat) block) {
    int idx = hasId(kvs) ? 0 : 1;
    //println("Updating the insert statement:");
    //println("- Was: <theInsert>");
    theCreate = block(theCreate);
    //println("- Became: <theInsert>");
    updateStep(idx, step(p.name, neo(executeNeoUpdate(p.name, neopp(theCreate))), myParams));
  }

  addSteps([ newId(myId) | !hasId(kvs) ]);
  
  // initialize
  updateSQLInsert(SQLStat(SQLStat ins) { return ins; });
  updateMongoInsert(DBObject(DBObject obj) { return obj; });
  updateNeoInsert(NeoStat(NeoStat create) { return create; });

  InsertContext ctx = <
    entity,
    myParams,
    sqlMe,
    mongoMe,
    cqlMe,
    neoMe,
    addSteps,
    updateSQLInsert,
    updateMongoInsert,
    updateNeoInsert,
    s
  >;
  
  
  theScript.steps += compileNeoNode(kvs, ctx);
  
  // this functions doesn't add steps
  // but modifies the mongo/sql insert
  // statements
  compileAttrs(p, [ kv | KeyVal kv <- kvs, isAttr(kv, entity, s), !isKeyValAttr(kv, entity, s) ], ctx);
  
  
  // Then we insert the keyval things
  // using the 'me' id as key for looking up
  
  lrel[str, KeyVal] keyValueDeps = [];
  for (KeyVal kv <- kvs, [str _, str kve] := isKeyValAttr(entity, kv has key ? "<kv.key>" : "@id", s)) {
    keyValueDeps += [<kve, kv>];
  } 
  
  for (str keyValEntity <- keyValueDeps<0>) {
    if (<<cassandra(), str dbName>, keyValEntity> <- s.placement) {
      list[str] colNames = [ cTyphonId(keyValEntity) ] 
        + [ cColName(keyValEntity, kv has key ? "<kv.key>" : "@id") | KeyVal kv <- keyValueDeps[keyValEntity] ];
      
      list[CQLExpr] vals = [cqlMe] 
        + [ expr2cql(e) | (KeyVal)`<Id _>: <Expr e>` <- keyValueDeps[keyValEntity] ];
      CQLStat cqlIns = cInsert(cTableName(keyValEntity), colNames, vals);
      addSteps([step(dbName, cassandra(cExecuteStatement(dbName, pp(cqlIns))), myParams)]);
    }
    else {
      throw "Cannot find <keyValEntity> on cassandra; bug";
    }
  }
  
  // Then we send off the freetext fields to the NLAE engine
  
  rel[str,str] analyses = {};
  for (KeyVal kv <- kvs, isFreeTextAttr(entity, kv has key ? "<kv.key>" : "@id", s)) {
  	str attr = "<kv.key>";
    Expr val = kv.\value;
    if ((Expr) `<Str string>` := val) {
    	analyses = getFreeTypeAnalyses(entity, kv has key ? "<kv.key>" : "@id", s);
    	str json = getProcessJson(nlpMe, entity, attr, "<string.contents>", analyses);
    	addSteps([step("nlae", nlp(process(json)), myParams)]);
    }
    else
    	throw "Expression for a freetext attribute can only be a string literal";
  } 
  
  
  for ((KeyVal)`<Id x>: <Expr ref>` <- kvs) {
  	maybePointer = expr2pointer(ref);
  	if (just(pointer) := maybePointer) {
  		str fromRole = "<x>"; 
    	if (Rel r:<entity, Cardinality _, fromRole, str _, Cardinality _, str to, bool _> <- s.rels) {
      		//println("COMPILING rel: <r>");
      	compileRefBinding(p, placeOf(to, s), entity, fromRole, r, pointer, ctx);
    	}
    }
  }
  
  // TODO : refs can be expressions
  for ((KeyVal)`<Id x>: [<{PlaceHolderOrUUID ","}* refs>]` <- kvs) {
    str fromRole = "<x>"; 
    //list[Pointer] pointers = [expr2pointer(r) | Expr r <- refs, (Expr) `<UUID _>`:= r, (Expr) `<Placeholder _>` := r];
    list[Pointer] pointers = refs2pointers([r | r <- refs]);
    if (Rel r:<entity, Cardinality _, fromRole, str _, Cardinality _, str to, bool _> <- s.rels) {
      compileRefBindingMany(p, placeOf(to, s), entity, fromRole, r, pointers, ctx);
    }
  }
  theScript.steps += [finish()];

  return theScript;
}

list[Step] compileNeoNode({KeyVal ","}* kvs, InsertContext ctx) {
	steps = [];
	visited = {};
	for (<<neo4j(), db>, edge> <- ctx.schema.placement) {
		if (r:<edge, _, _, _, _, entity, _> <- ctx.schema.rels, entity == ctx.entity) {
			if (entity notin visited) {
				str createStmt = 
					neopp(
						\nMatchUpdate(
							Maybe::nothing(), 
							nCreate(nPattern(nNodePattern("__n1", [ctx.entity], [nProperty(typhonId(ctx.entity), ctx.neoMe)]), [])), []));
				steps += [step(db, neo(executeNeoUpdate(db, createStmt)), ctx.myParams)];
				visited += {entity};
			}
		} 
	}
	return steps;
}

void compileAttrs(<DB::sql(), str dbName>, list[KeyVal] kvs, InsertContext ctx) {
  ctx.updateSQLInsert(SQLStat(SQLStat ins) {
     ins.colNames = [ *columnName(kv, ctx.entity) | KeyVal kv  <- kvs ] + [ lang::typhonql::relational::Util::typhonId(ctx.entity) ];
     ins.values =  [ *lang::typhonql::relational::Util::evalKeyVal(kv) | KeyVal kv <- kvs ] + [ ctx.sqlMe ];
     return ins;
  });
} 

void compileAttrs(<mongodb(), str dbName>, list[KeyVal] kvs, InsertContext ctx) {
  // todo: nested object literals are not compiled here
  ctx.updateMongoInsert(DBObject(DBObject obj) {
    obj.props += [ keyVal2prop(kv) | KeyVal kv <- kvs ] + [ <"_id", ctx.mongoMe> | !hasId(kvs) ];
    return obj;
  });
}

void compileAttrs(<neo4j(), str dbName>, list[KeyVal] kvs, InsertContext ctx) {
  ctx.updateNeoInsert(NeoStat(NeoStat create) {
     create.updateClause.pattern.rels[0].properties
     	 = [ nProperty(propertyName(kv, ctx.entity)[0], lang::typhonql::neo4j::NeoUtil::evalKeyVal(kv)[0]) | KeyVal kv  <- kvs ] 
     	 	+ [ nProperty(typhonId(ctx.entity), ctx.neoMe)];
     return create;
  });
} 
      

void compileRefBinding(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, true>,
  Pointer ref, InsertContext ctx
) {
  // update ref's foreign key to point to sqlMe
  str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
  SQLStat theUpdate = update(tableName(to), [\set(fk, ctx.sqlMe)],
    [where([equ(column(tableName(to), typhonId(to)), pointer2sql(ref))])]);
                
  ctx.addSteps([step(dbName, sql(executeStatement(dbName, pp(theUpdate))), ctx.myParams)]);

}
 
void compileRefBinding(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole,
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, true>,
  Pointer ref, InsertContext ctx
) {

  // insert entry in junction table between from and to on the current place.
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [pointer2sql(ref)], ctx.myParams));
  ctx.addSteps(insertIntoJunction(other, to, toRole, from, fromRole, pointer2sql(ref), [ctx.sqlMe], ctx.myParams));
}   
void compileRefBinding(
  <DB::sql(), str dbName>, <mongodb(), str other>, str from, str fromRole,
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, true>,
  Pointer ref, InsertContext ctx
) {
  // insert entry in junction table between from and to on the current place.
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [pointer2sql(ref)], ctx.myParams));
  ctx.addSteps(insertObjectPointer(other, to, toRole, toCard, pointer2mongo(ref), ctx.mongoMe, ctx.myParams));
}

//void compileRefBinding(
//  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole,
//  // parent = Product, parentRole = inventory, from = Item, fromRole = product
//  Rel r:<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true>,
//  UUID ref, InsertContext ctx
//) {
//  // set foreign key of sqlMe to point to uuid
//  println("DOING PARENT");
//  str fk = fkName(parent, from, fromRole == "" ? parentRole : fromRole);
//  ctx.updateSQLInsert(SQLStat(SQLStat theInsert) {
//    theInsert.colNames += [ fk ];
//    theInsert.values += [ lit(text(uuid2str(ref))) ];
//    return theInsert;
//  });
// }   

void compileRefBinding(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole,
  Rel r:<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true>,
  Pointer ref, InsertContext ctx
) {      
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, parent, parentRole, pointer2sql(ref), [ctx.sqlMe], ctx.myParams));
  ctx.addSteps(insertIntoJunction(other, parent, parentRole, from, fromRole, pointer2sql(ref), [ctx.sqlMe], ctx.myParams));
}


void compileRefBinding(
  <DB::sql(), str dbName>, <mongodb(), str other>, str from, str fromRole,
  Rel r:<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true>,
  Pointer ref, InsertContext ctx
) {
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, parent, parentRole, pointer2sql(ref), [ctx.sqlMe], ctx.myParams));
  ctx.addSteps(updateObjectPointer(other, parent, pointer2mongo(ref), ctx.mongoMe, ctx.myParams));
}

void compileRefBinding(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole,
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  Pointer ref, InsertContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> in ctx.schema.rels) {
    // it's an inverse of containment
    str fk = fkName(to, from, fromRole == "" ? toRole : fromRole);
    ctx.updateSQLInsert(SQLStat(SQLStat theInsert) {
      theInsert.colNames += [ fk ];
      theInsert.values += [ pointer2sql(ref) ];
      return theInsert;
    });
  }
  else {
    ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [pointer2sql(ref)], ctx.myParams));
  }
}

void compileRefBinding(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole,
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, false>,
  Pointer ref, InsertContext ctx
) {
  //if (r notin trueCrossRefs(ctx.schema.rels)) {
  //  fail compileRefBinding;
  //}
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [pointer2sql(ref)], ctx.myParams));
  ctx.addSteps(insertIntoJunction(other, to, toRole, from, fromRole, pointer2sql(ref), [ctx.sqlMe], ctx.myParams));
}

void compileRefBinding(
  <DB::sql(), str dbName>, <mongodb(), str other>, str from, str fromRole,
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, false>,
  Pointer ref, InsertContext ctx
) {
  //if (r notin trueCrossRefs(ctx.schema.rels)) {
  //  fail compileRefBinding;
  //}
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [pointer2sql(ref)], ctx.myParams));
  ctx.addSteps(updateObjectPointer(other, to, toRole, toCard, pointer2mongo(ref), ctx.mongoMe, ctx.myParams));
}

/*
For mongo the setting of a cross ref simply modifies the query
update object sent to insertOne. But modifications are done
to update the inverse direction.
*/

void compileRefBinding(
  <mongodb(), str dbName>, <mongodb(), dbName>, str from, str fromRole,
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, false>, 
  Pointer ref, InsertContext ctx
) {
  ctx.updateMongoInsert(DBObject(DBObject obj) {
    obj.props += [ <fromRole, pointer2mongo(ref)> ];
    return obj;
  });
  ctx.addSteps(insertObjectPointer(dbName, to, toRole, toCard, pointer2mongo(ref), ctx.mongoMe, ctx.myParams));
}

void compileRefBinding(
  <mongodb(), str dbName>, <mongodb(), str other:!dbName>, str from, str fromRole,
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, false>, 
  Pointer ref, InsertContext ctx
) {
  ctx.updateMongoInsert(DBObject(DBObject obj) {
    obj.props += [ <fromRole, pointer2mongo(ref)> ];
    return obj;
  });
  ctx.addSteps(insertObjectPointer(other, to, toRole, toCard, pointer2mongo(ref), ctx.mongoMe, ctx.myParams));
}

void compileRefBinding(
  <mongodb(), str dbName>, <DB::sql(), str other>, str from, str fromRole,
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, bool _>,
  Pointer ref, InsertContext ctx
) {
  ctx.updateMongoInsert(DBObject(DBObject obj) {
    obj.props += [ <fromRole, pointer2mongo(ref)> ];
    return obj;
  });
  ctx.addSteps(insertIntoJunction(other, to, toRole, from, fromRole, pointer2sql(ref), [ctx.sqlMe], ctx.myParams));
}

void updateNeoUpdate(str dbName,
  str from, str fromRole, str to,
  Pointer ref, InsertContext ctx) {
    ctx.updateNeoInsert(NeoStat(NeoStat create) {
   	 if (isEmpty(create.updateMatch.val.patterns)) { 
     	create.updateMatch.val.patterns += [ 
     		nPattern(
     			nNodePattern(fromRole, [to], []), 
     			[])];
     	create.updateMatch.val.clauses += 
     		[ nWhere([nEqu(nProperty(fromRole, "<to>.@id"), pointer2neo(ref))])];
 		create.updateClause.pattern.nodePattern =  nNodePattern(fromRole, [], []);
 		create.updateClause.pattern.rels[0].var = "r";
 		create.updateClause.pattern.rels[0].label = ctx.entity;    			
     }
     else {
     	create.updateMatch.val.patterns += [nPattern(
     			nNodePattern(fromRole, [to], []), 
     			[])];
     	create.updateMatch.val.clauses[0].exprs += 
     		[nEqu(nProperty(fromRole, "<to>.@id"), pointer2neo(ref))];
     	create.updateClause.pattern.rels[0].nodePattern.var = fromRole;
        	
     }
     /*create.update.pattern.nodePattern.properties
     	 = [ property(propertyName(kv, ctx.entity)[0], lang::typhonql::neo4j::NeoUtil::evalKeyVal(kv)[0]) | KeyVal kv  <- kvs ] 
     	 	+ [ property(typhonId(ctx.entity), ctx.neoMe)];*/
     return create;
  });
}

void compileRefBinding(
  <neo4j(), str dbName>, <mongodb(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, bool _>,
  Pointer ref, InsertContext ctx
) {// to mongo
   	updateNeoUpdate(dbName, from, fromRole, to, ref, ctx);
   	//if (r notin trueCrossRefs(ctx.schema.rels)) {
  	//  fail compileRefBinding;
  	//}
  	ctx.addSteps(updateObjectPointer(other, to, toRole, toCard, pointer2mongo(ref), ctx.mongoMe, ctx.myParams));
}

void compileRefBinding(
  <neo4j(), str dbName>, <DB::sql(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, bool _>,
  Pointer ref, InsertContext ctx
) {	
  // to sql
  updateNeoUpdate(dbName, from, fromRole, to, ref, ctx);
  ctx.addSteps(insertIntoJunction(other, to, toRole, from, fromRole, pointer2sql(ref), [ctx.sqlMe], ctx.myParams));
   
}

void compileRefBinding(
  <neo4j(), str _>, <neo4j(), _>, str from, str fromRole, 
  Rel r,
  Pointer ref, InsertContext ctx
) {
  throw "Relations between two Neo4J edges are not possible";
}


void compileRefBindingMany(
 <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole,
 Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
 list[Pointer] refs, InsertContext ctx
) {
  str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
  SQLStat theUpdate = update(tableName(to), [\set(fk, ctx.sqlMe)],
     [where([\in(column(tableName(to), typhonId(to)), [ pointer2sql(ref) | Pointer ref <- refs])])]);
                
  ctx.addSteps([step(dbName, sql(executeStatement(dbName, pp(theUpdate))), ctx.myParams)]);
}

void compileRefBindingMany(
 <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole,
 Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
 list[Pointer] refs, InsertContext ctx
) {
  // insert entry in junction table between from and to on the current place.
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [pointer2sql(ref) | Pointer ref <- refs ], ctx.myParams));
  ctx.addSteps([ *insertIntoJunction(other, to, toRole, from, fromRole, pointer2sql(ref), [ctx.sqlMe], ctx.myParams) | Pointer ref <- refs ]);
}

void compileRefBindingMany(
 <DB::sql(), str dbName>, <mongodb(), str other>, str from, str fromRole,
 Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
 list[Pointer] refs, InsertContext ctx
) {
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [pointer2sql(ref) | Pointer ref <- refs ], ctx.myParams));
  ctx.addSteps([ *insertObjectPointer(other, to, toRole, toCard, pointer2mongo(ref), ctx.mongoMe, ctx.myParams) 
                | Pointer ref <- refs ]);
} 

void compileRefBindingMany(
 <DB::sql(), str dbName>, _, str from, str fromRole,
 Rel r:<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true>,
 list[Pointer] refs, InsertContext ctx
) {
  throw "Cannot have multiple parents <refs> for inserted object <ctx.sqlMe>";
}


void compileRefBindingMany(
 <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole,
 Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
 list[Pointer] refs, InsertContext ctx
) {
  // save the cross ref
  ctx.addSteps([ *insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
    [ pointer2sql(ref) | Pointer ref <- refs ], ctx.myParams) ]);
}

void compileRefBindingMany(
 <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole,
 Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
 list[Pointer] refs, InsertContext ctx
) {
  ctx.addSteps([ *insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
    [ pointer2sql(ref) | Pointer ref <- refs ], ctx.myParams) ]);
    
  ctx.addSteps([*insertIntoJunction(other, to, toRole, from, fromRole, pointer2sql(ref), [ctx.sqlMe], ctx.myParams)
                  | Pointer ref <- refs ]);
}

void compileRefBindingMany(
 <DB::sql(), str dbName>, <mongodb(), str other>, str from, str fromRole,
 Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
 list[Pointer] refs, InsertContext ctx
) {
  ctx.addSteps([ *insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
    [ pointer2sql(ref) | Pointer ref <- refs ], ctx.myParams) ]);
  ctx.addSteps([*insertObjectPointer(other, to, toRole, toCard, pointer2mongo(ref), ctx.mongoMe, ctx.myParams)
                 | Pointer ref <- refs]);
}

void compileRefBindingMany(
 <mongodb(), str dbName>, <mongodb(), dbName>, str from, str fromRole,
 Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
 list[Pointer] refs, InsertContext ctx
) {
  ctx.updateMongoInsert(DBObject(DBObject obj) {
    obj.props += [ <fromRole, array([ pointer2mongo(ref) | Pointer ref <- refs ]) > ];
    return obj;
  });
  ctx.addSteps([ *insertObjectPointer(dbName, to, toRole, toCard, pointer2mongo(ref), ctx.mongoMe, ctx.myParams)
                | Pointer ref <- refs ]);
}

void compileRefBindingMany(
 <mongodb(), str dbName>, <mongodb(), str other:!dbName>, str from, str fromRole,
 Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
 list[Pointer] refs, InsertContext ctx
) {
  ctx.updateMongoInsert(DBObject(DBObject obj) {
    obj.props += [ <fromRole, array([ pointer2mongo(ref) | Pointer ref <- refs ]) > ];
    return obj;
  });
  ctx.addSteps([ *insertObjectPointer(other, to, toRole, toCard, pointer2mongo(ref) , ctx.mongoMe, ctx.myParams)
                | Pointer ref <- refs ]);
}

void compileRefBindingMany(
 <mongodb(), str dbName>, <DB::sql(), str other>, str from, str fromRole,
 Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
 list[Pointer] refs, InsertContext ctx
) {
  ctx.updateMongoInsert(DBObject(DBObject obj) {
    obj.props += [ <fromRole, array([ pointer2mongo(ref) | Pointer ref <- refs ]) > ];
    return obj;
  });
  ctx.addSteps([ *insertIntoJunction(other, to, toRole, from, fromRole, pointer2sql(ref), 
    [ctx.sqlMe], ctx.myParams) | Pointer ref <- refs ]);
}

void compileRefBindingMany(
  <DB::sql(), str dbName>, <neo4j(), str other>, str from, str fromRole,
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, true>,
  list[Pointer] refs, InsertContext ctx
) {
  // TODO
  // from sql
  //if (r notin trueCrossRefs(ctx.schema.rels)) {
  //  fail compileRefBinding;
  //}
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [pointer2sql(ref) | Pointer ref <- refs], ctx.myParams));
  //ctx.addSteps(updateObjectPointer(other, to, toRole, toCard, \value(uuid2str(ref)), ctx.mongoMe, ctx.myParams));
  
  ctx.addSteps([*neoReplaceEnd(other, to, from, toRole, pointer2neo(ref), ctx.neoMe, ctx.myParams, ctx.schema)| Pointer ref <- refs]);

}

void compileRefBindingMany(
  <mongodb(), str dbName>, <neo4j(), str other>, str from, str fromRole,
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, true>,
  list[Pointer] refs, InsertContext ctx
) {
  // TODO
  // from mongo 
  ctx.updateMongoInsert(DBObject(DBObject obj) {
    obj.props += [ <fromRole, array([ pointer2mongo(ref) | Pointer ref <- refs ]) > ];
    return obj;
  });
  
  ctx.addSteps([*neoReplaceEnd(other, to, from, toRole, pointer2neo(ref), ctx.neoMe, ctx.myParams, ctx.schema)| Pointer ref <- refs]);
}

void compileRefBindingMany(
  <neo4j(), str _>, <neo4j(), _>, str from, str fromRole, 
  Rel r,
  list[Pointer] ref, InsertContext ctx
) {
  throw "Relations between two Neo4J edges are not possible";
}

DBObject obj2dbObj((Expr)`<EId e> {<{KeyVal ","}* kvs>}`)
  = object([ keyVal2prop(kv) | KeyVal kv <- kvs ]);
   
//DBObject obj2dbObj((Expr)`[<{Obj ","}* objs>]`)
//  = array([ obj2dbObj((Expr)`<Obj obj>`) | Obj obj <- objs ]);

DBObject obj2dbObj((Expr)`[<{UUID ","}* refs>]`)
  = array([ obj2dbObj((Expr)`<UUID ref>`) | UUID ref <- refs ]);

DBObject obj2dbObj((Expr)`<Bool b>`) = \value("<b>" == "true");

DBObject obj2dbObj((Expr)`<Int n>`) = \value(toInt("<n>"));

DBObject obj2dbObj((Expr)`<PlaceHolder p>`) = placeholder(name="<p>"[2..]);

DBObject obj2dbObj((Expr)`<UUID id>`) = mUuid(uuid2str(id));

DBObject obj2dbObj((Expr)`#blob:<UUIDPart prt>`) = \value("#blob:<prt>");

DBObject obj2dbObj((Expr)`<DateTime d>`) 
  = \value(convert(d));


DBObject obj2dbObj((Expr)`#point(<Real x> <Real y>)`) 
  = object([<"type", \value("Point")>, 
      <"coordinates", array([\value(toReal("<x>")), \value(toReal("<y>"))])>]);

DBObject obj2dbObj((Expr)`#polygon(<{Segment ","}* segs>)`) 
  = object([<"type", \value("Polygon")>,
      <"coordinates", array([ seg2array(s) | Segment s <- segs ])>]);

DBObject seg2array((Segment)`(<{XY ","}* xys>)`)
  = array([ array([\value(toReal("<x>")), \value(toReal("<y>"))]) | (XY)`<Real x> <Real y>` <- xys ]);


DBObject obj2dbObj((Expr)`<Real r>`) = \value(toReal("<r>"));

DBObject obj2dbObj((Expr)`<Str x>`) = \value(unescapeQLString(x));
  
Prop keyVal2prop((KeyVal)`<Id x>: <Expr e>`) = <"<x>", obj2dbObj(e)>;
  
Prop keyVal2prop((KeyVal)`@id: <UUID u>`) = <"_id", mUuid(uuid2str(u))>;

bool isKeyValAttr((KeyVal)`<Id x>: <Expr _>`, str e, Schema s) 
  = isKeyValAttr(e, "<x>", s) != [];

default bool isKeyVal(KeyVal _, str _, Schema _) = false;

bool isAttr((KeyVal)`<Id x>: <Expr _>`, str e, Schema s) = <e, "<x>", _> <- s.attrs;

bool isAttr((KeyVal)`<Id x> +: <Expr _>`, str e, Schema s) = false;

bool isAttr((KeyVal)`<Id x> -: <Expr _>`, str e, Schema s) = false;

bool isAttr((KeyVal)`@id: <Expr _>`, str _, Schema _) = false;

Schema testSchema() = schema({
    <"Concordance", \one(), "from", "from^", \one(), "Product", false>,
    <"Concordance", \one(), "to", "to^", \one(), "Product", false>,
    <"Product", \one(), "from^", "from", \one(), "Concordance", true>,
    <"Product", \one(), "to^", "to", \one(), "Concordance", true>,
    <"Wish", \one(), "user", "userOpposite", \one(), "User", false>,
    <"Wish", \one(), "product", "productOpposite", \one(), "Product", false>,
    <"User", \one(), "wish", "user", \one(), "Wish", true>,
    <"Product", \one(), "wish", "product", \one(), "Concordance", true>
  }, {
    <"Concordance", "weight", "int">,
    <"Product", "name", "string[256]">,
    <"User", "name", "string[256]">,
    <"Wish", "amount", "int">
  },
  placement = {
    <<sql(), "Inventory">, "Product">,
    <<sql(), "Inventory">, "User">,
    <<neo4j(), "Concordance">, "Concordance">,
    <<neo4j(), "Concordance">, "Wish">
  },
  pragmas = {
  	<"Concordance", graphSpec({<"Concordance", "from", "to">, <"Wish", "user", "product">})>
  }
  );

/*
void smoke2sqlWithAllOnDifferentSQLDB() {
  s = schema({
    <"Person", zero_many(), "reviews", "user", \one(), "Review", true>,
    <"Review", \one(), "user", "reviews", \zero_many(), "Person", false>,
    <"Review", \one(), "comment", "owner", \zero_many(), "Comment", true>,
    <"Comment", zero_many(), "replies", "owner", \zero_many(), "Comment", true>
  }, {
    <"Person", "name", "String">,
    <"Person", "age", "int">,
    <"Review", "text", "String">,
    <"Comment", "contents", "String">,
    <"Reply", "reply", "String">
  },
  placement = {
    <<sql(), "Inventory">, "Person">,
    <<sql(), "Reviews">, "Review">,
    <<sql(), "Reviews">, "Comment">
  } 
  );
  
  return smoke2sql(s);
}

*/
void smoke2createWithAllOnSameNeoDB() {
  Schema s = testSchema();
	
  Request r = (Request)`insert Product { @id: #tv, name: "TV", description: "Dumb box"}`;  
  println(insert2script(r,s));
  if (step(_, neo(executeNeoUpdate(_, q)), _) := insert2script(r, s).steps[1]) {
  	println(q);
  }
  
  r = (Request)`insert Product { @id: #radio, name: "Radio", description: "TV without images"}`;  
  println(insert2script(r,s));
  if (step(_, neo(executeNeoUpdate(_, q)), _) := insert2script(r, s).steps[1]) {
  	println(q);
  }
  
  r = (Request)`insert User { @id: #pablo, name: "Pablo"}`;  
  println(insert2script(r,s));
  if (step(_, neo(executeNeoUpdate(_, q)), _) := insert2script(r, s).steps[1]) {
  	println(q);
  }
  
  
  r = (Request)`insert Concordance { @id: #conc1, from: #tv, to: #radio, weight: 15 }`;  
  println(insert2script(r,s));
  if (step(_, neo(executeNeoUpdate(_, q)), _) := insert2script(r, s).steps[0]) {
  	println(q);
  }
  
  r = (Request)`insert Wish { @id: #wish1, user: #pablo, product: #tv, amount: 15 }`;  
  println(insert2script(r,s));
  if (step(_, neo(executeNeoUpdate(_, q)), _) := insert2script(r, s).steps[0]) {
  	println(q);
  }
  
  
}

