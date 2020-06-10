module lang::typhonql::Insert2Script

import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::Script;
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

import IO;
import ValueIO;
import List;
import String;
import util::Maybe;

bool hasId({KeyVal ","}* kvs) = hasId([ kv | KeyVal kv <- kvs ]);

bool hasId(list[KeyVal] kvs) = any((KeyVal)`@id: <Expr _>` <- kvs);

str evalId({KeyVal ","}* kvs) = "<e>"[1..]
  when (KeyVal)`@id: <UUID e>` <- kvs;


str uuid2str(UUID ref) = "<ref>"[1..];

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
  SQLExpr sqlMe = hasId(kvs) ? SQLExpr::lit(text(evalId(kvs))) : SQLExpr::placeholder(name=myId);
  DBObject mongoMe = hasId(kvs) ? \value(evalId(kvs)) : DBObject::placeholder(name=myId);
  CQLExpr cqlMe = hasId(kvs) ? cTerm(cUUID(evalId(kvs))) : cBindMarker(name=myId);
  NeoExpr neoMe = hasId(kvs) ? NeoExpr::lit(text(evalId(kvs))) : NeoExpr::placeholder(name=myId);

  SQLStat theInsert = \insert(tableName("<e>"), [], []);
  DBObject theObject = object([ ]);
  NeoStat theCreate = \matchUpdate(Maybe::just(match([], [], [NeoExpr::lit(boolean(true))])), create(pattern(nodePattern("n", [], []), [relationshipPattern(doubleArrow(), "", "", [], nodePattern("", [], []))])));

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
    updateStep(idx, step(p.name, neo(executeNeoQuery(p.name, pp(theCreate))), myParams));
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
  
    
  
  for ((KeyVal)`<Id x>: <UUID ref>` <- kvs) {
    str fromRole = "<x>"; 
    if (Rel r:<entity, Cardinality _, fromRole, str _, Cardinality _, str to, bool _> <- s.rels) {
      //println("COMPILING rel: <r>");
      compileRefBinding(p, placeOf(to, s), entity, fromRole, r, ref, ctx);
    }
  }

  for ((KeyVal)`<Id x>: [<{UUID ","}* refs>]` <- kvs) {
    str fromRole = "<x>"; 
    if (Rel r:<entity, Cardinality _, fromRole, str _, Cardinality _, str to, bool _> <- s.rels) {
      compileRefBindingMany(p, placeOf(to, s), entity, fromRole, r, refs, ctx);
    }
  }
  theScript.steps += compileNeoNode(kvs, ctx);
  theScript.steps += [finish()];

  return theScript;
}

list[Step] compileNeoNode({KeyVal ","}* kvs, InsertContext ctx) {
	steps = [];
	for (<<neo4j(), db>, e> <- ctx.schema.placement) {
		if (<e, _, _, _, _, entity, _> <- ctx.schema.rels, entity == ctx.entity) {
			str createStmt = pp(\matchUpdate(Maybe::nothing(), 
				create(pattern(nodePattern("n", [nodeName("<ctx.entity>")], [property(typhonId(ctx.entity), ctx.neoMe)]), []))));
			steps += [step(db, neo(executeNeoQuery(db, createStmt)), ctx.myParams)];
		} 
	}
	return steps;
}

void compileAttrs(<DB::sql(), str dbName>, list[KeyVal] kvs, InsertContext ctx) {
  ctx.updateSQLInsert(SQLStat(SQLStat ins) {
     ins.colNames = [ *columnName(kv, ctx.entity) | KeyVal kv  <- kvs ] + [ lang::typhonql::relational::Util::typhonId(ctx.entity) ];
     ins.values =  [ *lang::typhonql::Insert2Script::evalKeyVal(kv) | KeyVal kv <- kvs ] + [ ctx.sqlMe ];
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
     	 = [ property(propertyName(kv, ctx.entity)[0], lang::typhonql::neo4j::NeoUtil::evalKeyVal(kv)[0]) | KeyVal kv  <- kvs ] 
     	 	+ [ property(typhonId(ctx.entity), ctx.neoMe)];
     return create;
  });
} 
      

void compileRefBinding(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, true>,
  UUID ref, InsertContext ctx
) {
  // update ref's foreign key to point to sqlMe
  str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
  SQLStat theUpdate = update(tableName(to), [\set(fk, ctx.sqlMe)],
    [where([equ(column(tableName(to), typhonId(to)), lit(text("<ref>"[1..])))])]);
                
  ctx.addSteps([step(dbName, sql(executeStatement(dbName, pp(theUpdate))), ctx.myParams)]);

}
 
void compileRefBinding(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole,
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, true>,
  UUID ref, InsertContext ctx
) {

  // insert entry in junction table between from and to on the current place.
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [lit(text("<ref>"[1..]))], ctx.myParams));
  ctx.addSteps(insertIntoJunction(other, to, toRole, from, fromRole, lit(text("<ref>"[1..])), [ctx.sqlMe], ctx.myParams));
}   
void compileRefBinding(
  <DB::sql(), str dbName>, <mongodb(), str other>, str from, str fromRole,
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, true>,
  UUID ref, InsertContext ctx
) {
  // insert entry in junction table between from and to on the current place.
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [lit(text("<ref>"[1..]))], ctx.myParams));
  ctx.addSteps(insertObjectPointer(other, to, toRole, toCard, \value("<ref>"[1..]), ctx.mongoMe, ctx.myParams));
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
  UUID ref, InsertContext ctx
) {      
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, parent, parentRole, lit(text(uuid2str(ref))), [ctx.sqlMe], ctx.myParams));
  ctx.addSteps(insertIntoJunction(other, parent, parentRole, from, fromRole, lit(text(uuid2str(ref))), [ctx.sqlMe], ctx.myParams));
}


void compileRefBinding(
  <DB::sql(), str dbName>, <mongodb(), str other>, str from, str fromRole,
  Rel r:<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true>,
  UUID ref, InsertContext ctx
) {
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, parent, parentRole, lit(text(uuid2str(ref))), [ctx.sqlMe], ctx.myParams));
  ctx.addSteps(updateObjectPointer(other, parent, parentRole, parentCard, \value(uuid2str(ref)), ctx.mongoMe, ctx.myParams));
}

void compileRefBinding(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole,
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  UUID ref, InsertContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> in ctx.schema.rels) {
    // it's an inverse of containment
    str fk = fkName(to, from, fromRole == "" ? toRole : fromRole);
    ctx.updateSQLInsert(SQLStat(SQLStat theInsert) {
      theInsert.colNames += [ fk ];
      theInsert.values += [ lit(text(uuid2str(ref))) ];
      return theInsert;
    });
  }
  else {
    ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [lit(text(uuid2str(ref)))], ctx.myParams));
  }
}

void compileRefBinding(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole,
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, false>,
  UUID ref, InsertContext ctx
) {
  //if (r notin trueCrossRefs(ctx.schema.rels)) {
  //  fail compileRefBinding;
  //}
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [lit(text(uuid2str(ref)))], ctx.myParams));
  ctx.addSteps(insertIntoJunction(other, to, toRole, from, fromRole, lit(text(uuid2str(ref))), [ctx.sqlMe], ctx.myParams));
}

void compileRefBinding(
  <DB::sql(), str dbName>, <mongodb(), str other>, str from, str fromRole,
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, false>,
  UUID ref, InsertContext ctx
) {
  //if (r notin trueCrossRefs(ctx.schema.rels)) {
  //  fail compileRefBinding;
  //}
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [lit(text(uuid2str(ref)))], ctx.myParams));
  ctx.addSteps(updateObjectPointer(other, to, toRole, toCard, \value(uuid2str(ref)), ctx.mongoMe, ctx.myParams));
}

/*
For mongo the setting of a cross ref simply modifies the query
update object sent to insertOne. But modifications are done
to update the inverse direction.
*/

void compileRefBinding(
  <mongodb(), str dbName>, <mongodb(), dbName>, str from, str fromRole,
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, false>, 
  UUID ref, InsertContext ctx
) {
  ctx.updateMongoInsert(DBObject(DBObject obj) {
    obj.props += [ <fromRole, \value(uuid2str(ref))> ];
    return obj;
  });
  ctx.addSteps(insertObjectPointer(dbName, to, toRole, toCard, \value(uuid2str(ref)), ctx.mongoMe, ctx.myParams));
}

void compileRefBinding(
  <mongodb(), str dbName>, <mongodb(), str other:!dbName>, str from, str fromRole,
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, false>, 
  UUID ref, InsertContext ctx
) {
  ctx.updateMongoInsert(DBObject(DBObject obj) {
    obj.props += [ <fromRole, \value(uuid2str(ref))> ];
    return obj;
  });
  ctx.addSteps(insertObjectPointer(other, to, toRole, toCard, \value(uuid2str(ref)), ctx.mongoMe, ctx.myParams));
}

void compileRefBinding(
  <mongodb(), str dbName>, <DB::sql(), str other>, str from, str fromRole,
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, bool _>,
  UUID ref, InsertContext ctx
) {
  ctx.updateMongoInsert(DBObject(DBObject obj) {
    obj.props += [ <fromRole, \value(uuid2str(ref))> ];
    return obj;
  });
  ctx.addSteps(insertIntoJunction(other, to, toRole, from, fromRole, lit(text(uuid2str(ref))), [ctx.sqlMe], ctx.myParams));
}

void compileRefBinding(
  <neo4j(), str _>, <neo4j(), _>, str from, str fromRole, 
  Rel r,
  UUID ref, InsertContext ctx
) {
  throw "Relations between two Neo4J edges are not possible";
}

default void compileRefBinding(
  <neo4j(), str dbName>, <_, str other>, str from, str fromRole, 
  Rel r:<from, Cardinality _, fromRole, str toRole, Cardinality toCard, str to, bool _>,
  UUID ref, InsertContext ctx
) {
   ctx.updateNeoInsert(NeoStat(NeoStat create) {
   	 if (isEmpty(create.updateMatch.val.patterns)) { 
     	create.updateMatch.val.patterns += [ 
     		pattern(
     			nodePattern(fromRole, [to], []), 
     			[])];
     	create.updateMatch.val.clauses += 
     		[ where([equ(property(fromRole, "<to>.@id"), lit(text("<ref>"[1..])))])];
 		create.updateClause.pattern.nodePattern =  nodePattern(fromRole, [], []);
 		create.updateClause.pattern.rels[0].var = "r";
 		create.updateClause.pattern.rels[0].label = ctx.entity;    			
     }
     else {
     	create.updateMatch.val.patterns += [pattern(
     			nodePattern(fromRole, [to], []), 
     			[])];
     	create.updateMatch.val.clauses[0].exprs += 
     		[equ(property(fromRole, "<to>.@id"), lit(text("<ref>"[1..])))];
     	create.updateClause.pattern.rels[0].nodePattern.var = fromRole;
        	
     }
     /*create.update.pattern.nodePattern.properties
     	 = [ property(propertyName(kv, ctx.entity)[0], lang::typhonql::neo4j::NeoUtil::evalKeyVal(kv)[0]) | KeyVal kv  <- kvs ] 
     	 	+ [ property(typhonId(ctx.entity), ctx.neoMe)];*/
     return create;
  });
}

void compileRefBindingMany(
 <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole,
 Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
 {UUID ","}* refs, InsertContext ctx
) {
  str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
  SQLStat theUpdate = update(tableName(to), [\set(fk, ctx.sqlMe)],
     [where([\in(column(tableName(to), typhonId(to)), [ evalExpr((Expr)`<UUID ref>`) | UUID ref <- refs])])]);
                
  ctx.addSteps([step(dbName, sql(executeStatement(dbName, pp(theUpdate))), ctx.myParams)]);
}

void compileRefBindingMany(
 <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole,
 Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
 {UUID ","}* refs, InsertContext ctx
) {
  // insert entry in junction table between from and to on the current place.
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams));
  ctx.addSteps([ *insertIntoJunction(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), [ctx.sqlMe], ctx.myParams) | UUID ref <- refs ]);
}

void compileRefBindingMany(
 <DB::sql(), str dbName>, <mongodb(), str other>, str from, str fromRole,
 Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
 {UUID ","}* refs, InsertContext ctx
) {
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams));
  ctx.addSteps([ *insertObjectPointer(other, to, toRole, toCard, \value("<ref>"[1..]), ctx.mongoMe, ctx.myParams) 
                | UUID ref <- refs ]);
} 

void compileRefBindingMany(
 <DB::sql(), str dbName>, _, str from, str fromRole,
 Rel r:<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true>,
 {UUID ","}* refs, InsertContext ctx
) {
  throw "Cannot have multiple parents <refs> for inserted object <ctx.sqlMe>";
}


void compileRefBindingMany(
 <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole,
 Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
 {UUID ","}* refs, InsertContext ctx
) {
  // save the cross ref
  ctx.addSteps([ *insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
    [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams) ]);
}

void compileRefBindingMany(
 <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole,
 Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
 {UUID ","}* refs, InsertContext ctx
) {
  ctx.addSteps([ *insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
    [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams) ]);
    
  ctx.addSteps([*insertIntoJunction(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), [ctx.sqlMe], ctx.myParams)
                  | UUID ref <- refs ]);
}

void compileRefBindingMany(
 <DB::sql(), str dbName>, <mongodb(), str other>, str from, str fromRole,
 Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
 {UUID ","}* refs, InsertContext ctx
) {
  ctx.addSteps([ *insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
    [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams) ]);
  ctx.addSteps([*insertObjectPointer(other, to, toRole, toCard, \value("<ref>"[1..]), ctx.mongoMe, ctx.myParams)
                 | UUID ref <- refs]);
}

void compileRefBindingMany(
 <mongodb(), str dbName>, <mongodb(), dbName>, str from, str fromRole,
 Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
 {UUID ","}* refs, InsertContext ctx
) {
  ctx.updateMongoInsert(DBObject(DBObject obj) {
    obj.props += [ <fromRole, array([ \value(uuid2str(ref)) | UUID ref <- refs ]) > ];
    return obj;
  });
  ctx.addSteps([ *insertObjectPointer(dbName, to, toRole, toCard, \value(uuid2str(ref)) , ctx.mongoMe, ctx.myParams)
                | UUID ref <- refs ]);
}

void compileRefBindingMany(
 <mongodb(), str dbName>, <mongodb(), str other:!dbName>, str from, str fromRole,
 Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
 {UUID ","}* refs, InsertContext ctx
) {
  ctx.updateMongoInsert(DBObject(DBObject obj) {
    obj.props += [ <fromRole, array([ \value(uuid2str(ref)) | UUID ref <- refs ]) > ];
    return obj;
  });
  ctx.addSteps([ *insertObjectPointer(other, to, toRole, toCard, \value(uuid2str(ref)) , ctx.mongoMe, ctx.myParams)
                | UUID ref <- refs ]);
}

void compileRefBindingMany(
 <mongodb(), str dbName>, <DB::sql(), str other>, str from, str fromRole,
 Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
 {UUID ","}* refs, InsertContext ctx
) {
  ctx.updateMongoInsert(DBObject(DBObject obj) {
    obj.props += [ <fromRole, array([ \value(uuid2str(ref)) | UUID ref <- refs ]) > ];
    return obj;
  });
  ctx.addSteps([ *insertIntoJunction(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), 
    [ctx.sqlMe], ctx.myParams) | UUID ref <- refs ]);
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

DBObject obj2dbObj((Expr)`<UUID id>`) = \value("<id>"[1..]);

DBObject obj2dbObj((Expr)`<DateTime d>`) 
  = object([<"$date", \value(readTextValueString(#datetime, "<d>"))>]);

DBObject obj2dbObj((Expr)`#point(<Real x> <Real y>)`) 
  = object([<"type", \value("Point")>, 
      <"coordinates", array([\value(toReal("<x>")), \value(toReal("<y>"))])>]);

DBObject obj2dbObj((Expr)`#polygon(<{Segment ","}* segs>)`) 
  = object([<"type", \value("Polygon")>,
      <"coordinates", array([ seg2array(s) | Segment s <- segs ])>]);

DBObject seg2array((Segment)`(<{XY ","}* xys>)`)
  = array([ array([\value(toReal("<x>")), \value(toReal("<y>"))]) | (XY)`<Real x> <Real y>` <- xys ]);


DBObject obj2dbObj((Expr)`<Real r>`) = \value(toReal("<r>"));

// todo: unescaping
DBObject obj2dbObj((Expr)`<Str x>`) = \value("<x>"[1..-1]);
  
Prop keyVal2prop((KeyVal)`<Id x>: <Expr e>`) = <"<x>", obj2dbObj(e)>;
  
Prop keyVal2prop((KeyVal)`@id: <UUID u>`) = <"_id", \value("<u>"[1..])>;
  

list[str] columnName((KeyVal)`<Id x>: <EId customType> (<{KeyVal ","}* keyVals>)`, str entity) = [columnName("<x>", entity, "<customType>", "<y>") | (KeyVal)`<Id y>: <Expr e>` <- keyVals];

list[str] columnName((KeyVal)`<Id x>: <Expr e>`, str entity) = [columnName("<x>", entity)]
	when (Expr) `<Custom c>` !:= e;

list[str] columnName((KeyVal)`@id: <Expr _>`, str entity) = [typhonId(entity)]; 

list[SQLExpr] evalKeyVal((KeyVal) `<Id x>: <EId customType> (<{KeyVal ","}* keyVals>)`) 
  = [lit(evalExpr(e)) | (KeyVal)`<Id x>: <Expr e>` <- keyVals];

list[SQLExpr] evalKeyVal((KeyVal)`<Id _>: <Expr e>`) = [lang::typhonql::relational::SQL::lit(evalExpr(e))]
	when (Expr) `<Custom c>` !:= e;

list[SQLExpr] evalKeyVal((KeyVal)`@id: <Expr e>`) = [lit(evalExpr(e))];

Value evalExpr((Expr)`<VId v>`) { throw "Variable still in expression"; }
 
// todo: unescaping (e.g. \" to ")!
Value evalExpr((Expr)`<Str s>`) = text("<s>"[1..-1]);

Value evalExpr((Expr)`<Int n>`) = integer(toInt("<n>"));

Value evalExpr((Expr)`<Bool b>`) = boolean("<b>" == "true");

Value evalExpr((Expr)`<Real r>`) = decimal(toReal("<r>"));

Value evalExpr((Expr)`#point(<Real x> <Real y>)`) = point(toReal("<x>"), toReal("<y>"));

Value evalExpr((Expr)`#polygon(<{Segment ","}* segs>)`)
  = polygon([ seg2lrel(s) | Segment s <- segs ]);
  
lrel[real, real] seg2lrel((Segment)`(<{XY ","}* xys>)`)
  = [ <toReal("<x>"), toReal("<y>")> | (XY)`<Real x> <Real y>` <- xys ]; 

Value evalExpr((Expr)`<DateAndTime d>`) = dateTime(readTextValueString(#datetime, "<d>"));

Value evalExpr((Expr)`<JustDate d>`) = date(readTextValueString(#datetime, "<d>"));

// should only happen for @id field (because refs should be done via keys etc.)
Value evalExpr((Expr)`<UUID u>`) = text("<u>"[1..]);

Value evalExpr((Expr)`<PlaceHolder p>`) = placeholder(name="<p>"[2..]);

default Value evalExpr(Expr ex) { throw "missing case for <ex>"; }

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
  if (step(_, neo(executeNeoQuery(_, q)), _) := insert2script(r, s).steps[1]) {
  	println(q);
  }
  
  r = (Request)`insert Product { @id: #radio, name: "Radio", description: "TV without images"}`;  
  println(insert2script(r,s));
  if (step(_, neo(executeNeoQuery(_, q)), _) := insert2script(r, s).steps[1]) {
  	println(q);
  }
  
  r = (Request)`insert User { @id: #pablo, name: "Pablo"}`;  
  println(insert2script(r,s));
  if (step(_, neo(executeNeoQuery(_, q)), _) := insert2script(r, s).steps[1]) {
  	println(q);
  }
  
  
  r = (Request)`insert Concordance { @id: #conc1, from: #tv, to: #radio, weight: 15 }`;  
  println(insert2script(r,s));
  if (step(_, neo(executeNeoQuery(_, q)), _) := insert2script(r, s).steps[0]) {
  	println(q);
  }
  
  r = (Request)`insert Wish { @id: #wish1, user: #pablo, product: #tv, amount: 15 }`;  
  println(insert2script(r,s));
  if (step(_, neo(executeNeoQuery(_, q)), _) := insert2script(r, s).steps[0]) {
  	println(q);
  }
  
  
}
