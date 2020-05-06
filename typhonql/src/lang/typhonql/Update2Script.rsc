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


import IO;
import List;
import String;


bool isDelta((KeyVal)`<Id _> +: <Expr _>`) = true;
bool isDelta((KeyVal)`<Id _> -: <Expr _>`) = true;
default bool isDelta(KeyVal _) = false;


alias UpdateContext = tuple[
  str entity,
  Bindings myParams,
  SQLExpr sqlMe,
  DBObject mongoMe,
  void (list[Step]) addSteps,
  void (SQLStat(SQLStat)) updateSQLUpdate,
  void (DBObject(DBObject)) updateMongoUpdate,
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
  Bindings myParams = ( myId: toBeUpdated );
  
  
  if ((Where)`where <VId _>.@id == <UUID mySelf>` := (Where)`where <{Expr ","}+ ws>`) {
    sqlMe = lit(evalExpr((Expr)`<UUID mySelf>`));
    mongoMe = \value(uuid2str(mySelf));
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
    Step st = step(p.name, mongo(findAndUpdateOne(p.name, ent, pp(theFilter), pp(theObject))), myParams);
    updateStep(statIndex, st);
  }
  
  updateMongoUpdate(DBObject(DBObject d) { return d; });
  
  
  UpdateContext ctx = <
    ent,
    myParams,
    sqlMe,
    mongoMe,
    addSteps,
    updateSQLUpdate,
    updateMongoUpdate,
    s
  >;
  
  compileAttrSets(p, [ kv | KeyVal kv <- kvs, isAttr(kv, ent, s) ], ctx);

  // TODO: make less ugly how the rel is looked up here in if-statements (also with insert)
  for ((KeyVal)`<Id x>: <UUID ref>` <- kvs) {
    str fromRole = "<x>"; 
    if (Rel r:<entity, Cardinality _, fromRole, str _, Cardinality _, str to, bool _> <- s.rels) {
      //println("COMPILING rel: <r>");
      compileRefSet(p, placeOf(to, s), entity, fromRole, r, ref, ctx);
    }
  }

  for ((KeyVal)`<Id x>: [<{UUID ","}* refs>]` <- kvs) {
    str fromRole = "<x>"; 
    if (Rel r:<entity, Cardinality _, fromRole, str _, Cardinality _, str to, bool _> <- s.rels) {
      compileRefSetMany(p, placeOf(to, s), entity, fromRole, r, refs, ctx);
    }
  }

  for ((KeyVal)`<Id x> +: [<{UUID ","}* refs>]` <- kvs) {
    str fromRole = "<x>"; 
    if (Rel r:<entity, Cardinality _, fromRole, str _, Cardinality _, str to, bool _> <- s.rels) {
      compileRefAddTo(p, placeOf(to, s), entity, fromRole, r, refs, ctx);
    }
  }

  for ((KeyVal)`<Id x> -: [<{UUID ","}* refs>]` <- kvs) {
    str fromRole = "<x>"; 
    if (Rel r:<entity, Cardinality _, fromRole, str _, Cardinality _, str to, bool _> <- s.rels) {
      compileRefRemoveFrom(p, placeOf(to, s), entity, fromRole, r, refs, ctx);
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
    upd.sets += [ Set::\set(columnName("<kv.key>", ctx.entity), SQLExpr::lit(evalExpr(kv.\value))) | KeyVal kv <- kvs ];
    return upd;
  });

 }
 
void compileAttrSets(<mongodb(), str dbName>, list[KeyVal] kvs, UpdateContext ctx) {
  ctx.updateMongoUpdate(DBObject(DBObject upd) {
    upd.props += [ <"$set", object([keyVal2prop(kv)])> | KeyVal kv <- kvs ];
    return upd;
  });
}


/*
 * Assign to a relation, single-valued
 */

// sql/same sql containment
void compileRefSet(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  UUID ref, UpdateContext ctx
) {
  // update ref's foreign key to point to sqlMe
  str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
  SQLStat theUpdate = update(tableName(to), [\set(fk, ctx.sqlMe)],
    [where([equ(column(tableName(to), typhonId(to)), lit(text(uuid2str(ref))))])]);
  ctx.addSteps([step(dbName, sql(executeStatement(dbName, pp(theUpdate))), ctx.myParams)]);
}
 
 // sql/other sql containment
void compileRefSet(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  UUID ref, UpdateContext ctx
) {
   // it's single ownership, so dont' insert in the junction but update.
  ctx.addSteps(updateIntoJunctionSingle(dbName, from, fromRole, to, toRole, ctx.sqlMe, lit(text(uuid2str(ref))), ctx.myParams));
  ctx.addSteps(updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(text(uuid2str(ref))), ctx.sqlMe, ctx.myParams));
}
 
 // sql/mongo containment
void compileRefSet(
  <DB::sql(), str dbName>, <mongodb(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  UUID ref, UpdateContext ctx
) {
  ctx.addSteps(updateIntoJunctionSingle(dbName, from, fromRole, to, toRole, ctx.sqlMe, lit(text(uuid2str(ref))), ctx.myParams));
  ctx.addSteps(updateObjectPointer(other, to, toRole, toCard, \value(uuid2str(ref)), ctx.mongoMe, ctx.myParams));
} 

// <str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true> 
// this is the case that the current KeyVal pair is actually
// setting the currently updated object as being owned by ref
           
// sql/same sql co-containment           
void compileRefSet(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole, 
  Rel r:<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true>,
  UUID ref, UpdateContext ctx
) {
  // update "my" foreign key to point to uuid
  ctx.updateSQLUpdate(SQLStat(SQLStat upd) {
    str fk = fkName(parent, from, fromRole == "" ? parentRole : fromRole);
    upd.sets += [\set(fk, lit(text(uuid2str(ref))))];
    return upd;
  });
}

// sql/other sql co-containment
void compileRefSet(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole, 
  Rel r:<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true>,
  UUID ref, UpdateContext ctx
) {
  // it's single ownership, so dont' insert in the junction but update.
  ctx.addSteps(updateIntoJunctionSingle(dbName, from, fromRole, parent, parentRole, lit(text(uuid2str(ref))), ctx.sqlMe, ctx.myParams));
  ctx.addSteps(updateIntoJunctionSingle(other, parent, parentRole, from, fromRole, lit(text(uuid2str(ref))), ctx.sqlMe, ctx.myParams));
}

// sql/mongo containment
void compileRefSet(
  <DB::sql(), str dbName>, <DB::mongodb(), str other>, str from, str fromRole, 
  Rel r:<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true>,
  UUID ref, UpdateContext ctx
) {
  ctx.addSteps(updateIntoJunctionSingle(dbName, from, fromRole, parent, parentRole, lit(text(uuid2str(ref))), ctx.sqlMe, ctx.myParams));
  ctx.addSteps(updateObjectPointer(other, parent, parentRole, parentCard, \value(uuid2str(ref)), ctx.mongoMe, ctx.myParams));
}

// mongo/same mongo containment or xref
void compileRefSet(
  <DB::mongodb(), str dbName>, <DB::mongodb(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  UUID ref, UpdateContext ctx
) {
  ctx.updateMongoUpdate(DBObject(DBObject upd) {
    upd.props += [ <"$set", \value(uuid2str(ref))> ];
    return upd;
  });
  ctx.addSteps(updateObjectPointer(dbName, to, toRole, toCard, \value(uuid2str(ref)), ctx.mongoMe, ctx.myParams));
}

// mongo/other mongo containment or xref
void compileRefSet(
  <DB::mongodb(), str dbName>, <DB::mongodb(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  UUID ref, UpdateContext ctx
) {
  ctx.updateMongoUpdate(DBObject(DBObject upd) {
    upd.props += [ <"$set", \value(uuid2str(ref))> ];
    return upd;
  });
  ctx.addSteps(updateObjectPointer(other, to, toRole, toCard, \value(uuid2str(ref)), ctx.mongoMe, ctx.myParams));
}

// mongo/sql containment or xref
void compileRefSet(
  <DB::mongodb(), str dbName>, <DB::sql(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  UUID ref, UpdateContext ctx
) {
  ctx.updateMongoUpdate(DBObject(DBObject upd) {
    upd.props += [ <"$set", \value(uuid2str(ref))> ];
    return upd;
  });
  ctx.addSteps(updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(text(uuid2str(ref))), ctx.sqlMe, ctx.myParams));
}

// sql/same sql xref
void compileRefSet(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  UUID ref, UpdateContext ctx
) {
  // save the cross ref
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    // inverse of containment, the target `to` owns sqlMe, so modify the update
    // to include foreign key. TODO: is this the same case as with `parent`?
    // [probably that one should be dropped]
    ctx.updateSQLUpdate(SQLStat(SQLStat upd) {
      str fk = fkName(parent, from, fromRole == "" ? parentRole : fromRole);
      upd.sets += [\set(fk, lit(text(uuid2str(ref))))];
      return upd;
    });
  }
  else {
    ctx.addSteps(updateIntoJunctionSingle(dbName, from, fromRole, to, toRole, ctx.sqlMe, lit(text(uuid2str(ref))), ctx.myParams));
  }
}
// sql/other sql xref
void compileRefSet(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  UUID ref, UpdateContext ctx
) {
  ctx.addSteps(updateIntoJunctionSingle(dbName, from, fromRole, to, toRole, ctx.sqlMe, lit(text(uuid2str(ref))), ctx.myParams));
  ctx.addSteps(updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(text(uuid2str(ref))), ctx.sqlMe, ctx.myParams));
}

// sql/mongo xref
void compileRefSet(
  <DB::sql(), str dbName>, <DB::mongodb(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  UUID ref, UpdateContext ctx
) {
  ctx.addSteps(updateIntoJunctionSingle(dbName, from, fromRole, to, toRole, ctx.sqlMe, lit(text(uuid2str(ref))), ctx.myParams));
  ctx.addSteps(updateObjectPointer(other, to, toRole, toCard, \value(uuid2str(ref)), ctx.mongoMe, ctx.myParams));
}


/* 
 * Many-valued set
 */

// sql/same sql containment
void compileRefSetMany(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  {UUID ","}* refs, UpdateContext ctx
) {
  // update each ref's foreign key to point to sqlMe
  str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
  SQLStat theUpdate = update(tableName(to), [\set(fk, ctx.sqlMe)],
    [where([\in(column(tableName(to), typhonId(to)), [ evalExpr((Expr)`<UUID ref>`) | UUID ref <- refs ])])]);
    
  ctx.addSteps([step(dbName, sql(executeStatement(dbName, pp(theUpdate))), ctx.myParams)]);
}

// sql/other sql containment
void compileRefSetMany(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  {UUID ","}* refs, UpdateContext ctx
) {
  ctx.addSteps(updateIntoJunctionMany(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
    [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams));
  // NB: ownership is never many to many, so if fromRole is many, toRole cannot be
  ctx.addSteps([ *updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), ctx.sqlMe, ctx.myParams)
    | UUID ref <- refs ]);
}

// sql/mongo containment
void compileRefSetMany(
  <DB::sql(), str dbName>, <DB::mongodb(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  {UUID ","}* refs, UpdateContext ctx
) {
  ctx.addSteps(updateIntoJunctionMany(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
     [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams));
  
  // NB: ownership is never many to many, so if fromRole is many, toRole cannot be
  ctx.addSteps([ *updateObjectPointer(other, to, toRole, toCard, \value(uuid2str(ref)), ctx.mongoMe, ctx.myParams) 
      | UUID ref <- refs ]);

 // we need to delete all Mongo objects in role that have a ref to mongome via toRole
 // whose _id is not in refs.
  DBObject q = object([<"_id", object([<"$nin", array([ \value(uuid2str(ref)) | UUID ref <- refs ])>])>
     , <toRole, ctx.mongoMe>]);
  ctx.addSteps([ step(other, mongo(deleteMany(other, to, pp(q))), ctx.myParams)]);
}

// sql/same sql xref
void compileRefSetMany(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  {UUID ","}* refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(updateIntoJunctionMany(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
    [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams));
}

// sql/other sql xref
void compileRefSetMany(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  {UUID ","}* refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(updateIntoJunctionMany(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
    [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams));
  ctx.addSteps([ *updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), ctx.sqlMe, ctx.myParams)
                 | UUID ref <- refs ]);
}

// sql/mongo xref
void compileRefSetMany(
  <DB::sql(), str dbName>, <DB::mongodb(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  {UUID ","}* refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  // todo: deal with multiplicity correctly in updateObject Pointer
  ctx.addSteps([ *updateObjectPointer(other, to, toRole, toCard, \value(uuid2str(ref)), ctx.mongoMe, ctx.myParams) 
      | UUID ref <- refs ]);
}

// mongo/same mongo containment or xref
void compileRefSetMany(
  <DB::mongodb(), str dbName>, <DB::mongodb(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  {UUID ","}* refs, UpdateContext ctx
) {
  ctx.updateMongoUpdate(DBObject(DBObject upd) {
    upd.props += [ <"$set", array([ \value(uuid2str(ref )) | UUID ref <- refs ])> ];
    return upd;
  });
  ctx.addSteps([ *updateObjectPointer(dbName, to, toRole, toCard, \value(uuid2str(ref)), ctx.mongoMe, ctx.myParams)
                | UUID ref <- refs ]);
                
  // we need to update all Mongo objects that have a pointer to mongoMe via toRole
  // whose _id is not in refs, and in case of containment, delete them [do we have containment that is not native in Mongo?]
  
  DBObject q = object([<"_id", object([<"$nin", array([ \value(uuid2str(ref)) | UUID ref <- refs ])>])>, <toRole, ctx.mongoMe>]);
  DBObject u = object([<"$set", object([<toRole, object([<"$set", DBObject::null()>])>])>]); 
  if (toCard in {zero_many(), one_many()}) { 
    u = object([<"$pull", 
               object([<toRole, 
                 object([<"$in", array([ ctx.mongoMe ])>])>])>]);
  }              
  ctx.addSteps([ step(dbName, mongo(findAndUpdateMany(dbName, to, pp(q), pp(u))), ctx.myParams)]); 
}

// mongo/other mongo containment or xref
void compileRefSetMany(
  <DB::mongodb(), str dbName>, <DB::mongodb(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  {UUID ","}* refs, UpdateContext ctx
) {
  ctx.updateMongoUpdate(DBObject(DBObject upd) {
    upd.props += [ <"$set", array([ \value(uuid2str(ref )) | UUID ref <- refs ])> ];
    return upd;
  });
  ctx.addSteps([ *updateObjectPointer(other, to, toRole, toCard, \value(uuid2str(ref)), ctx.mongoMe, ctx.myParams)
                | UUID ref <- refs ]);

  // we need to update all Mongo objects that have a pointer to mongoMe via toRole
  // whose _id is not in refs, and in case of containment, delete them [do we have containment that is not native in Mongo?]
  
  DBObject q = object([<"_id", object([<"$nin", array([ \value(uuid2str(ref)) | UUID ref <- refs ])>])>, <toRole, ctx.mongoMe>]);
  DBObject u = object([<"$set", object([<toRole, object([<"$set", null()>])>])>]); 
  if (toCard in {zero_many(), one_many()}) { 
    u = object([<"$pull", 
               object([<toRole, 
                 object([<"$in", array([ ctx.mongoMe ])>])>])>]);
  }              
  ctx.addSteps([ step(other, mongo(findAndUpdateMany(dbName, to, pp(q), pp(u))), ctx.myParams)]);              
}

// mongo/sql containment or xref
void compileRefSetMany(
  <DB::mongodb(), str dbName>, <DB::mongodb(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  {UUID ","}* refs, UpdateContext ctx
) {
  ctx.updateMongoUpdate(DBObject(DBObject upd) {
    upd.props += [ <"$set", array([ \value(uuid2str(ref )) | UUID ref <- refs ])> ];
    return upd;
  });
  ctx.addSteps([ *updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), ctx.sqlMe, ctx.myParams)
                | UUID ref <- refs ]);
}


/*
 * Adding to many-valued collections
 */
 
// sql/same sql containment 
void compileRefAddTo(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  {UUID ","}* refs, UpdateContext ctx
) {
  // update each ref's foreign key to point to sqlMe
  str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
  SQLStat theUpdate = update(tableName(to), [\set(fk, ctx.sqlMe)],
    [where([\in(column(tableName(to), typhonId(to)), [ evalExpr((Expr)`<UUID ref>`) | UUID ref <- refs ])])]);
    
  ctx.addSteps([step(dbName, sql(executeStatement(dbName, pp(theUpdate))), ctx.myParams)]);
}  

// sql/other sql containment
void compileRefAddTo(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  {UUID ","}* refs, UpdateContext ctx
) {
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
     [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams));
  // NB: ownership is never many to many, so if fromRole is many, toRole cannot be
  ctx.addSteps([ *updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), ctx.sqlMe, ctx.myParams)
    | UUID ref <- refs ]);
}

// sql/mongo containment
void compileRefAddTo(
  <DB::sql(), str dbName>, <DB::mongodb(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  {UUID ","}* refs, UpdateContext ctx
) {
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
    [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams));
  
  // NB: ownership is never many to many, so if fromRole is many, toRole cannot be
  ctx.addSteps([ *updateObjectPointer(other, to, toRole, toCard, \value(uuid2str(ref)), ctx.mongoMe, ctx.myParams) 
      | UUID ref <- refs ]);
}

// sql/same sql xref 
void compileRefAddTo(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  {UUID ","}* refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  // save the cross ref
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams));
}
  
// sql/other sql xref
void compileRefAddTo(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  {UUID ","}* refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams));
  ctx.addSteps([ *insertIntoJunctionSingle(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), ctx.sqlMe, ctx.myParams)
                 | UUID ref <- refs ]);
}

// sql/mongo xref
void compileRefAddTo(
  <DB::sql(), str dbName>, <DB::mongodb(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  {UUID ","}* refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams));
  // todo: deal with multiplicity correctly in updateObject Pointer
  ctx.addSteps([ *updateObjectPointer(other, to, toRole, toCard, \value(uuid2str(ref)), ctx.mongoMe, ctx.myParams) 
      | UUID ref <- refs ]);
}

// mongo/same mongo containment or xref
void compileRefAddTo(
  <DB::mongodb(), str dbName>, <DB::mongodb(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  {UUID ","}* refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(insertObjectPointers(dbName, from, fromRole, fromCard, ctx.mongoMe, 
             [ \value(uuid2str(ref)) | UUID ref <- refs ], ctx.myParams));
  ctx.addSteps([ *insertObjectPointer(dbName, to, toRole, toCard, \value(uuid2str(ref)) , ctx.mongoMe, ctx.myParams)
                | UUID ref <- refs ]);
}

// mongo/other mongo containment or xref
void compileRefAddTo(
  <DB::mongodb(), str dbName>, <DB::mongodb(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  {UUID ","}* refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(insertObjectPointers(dbName, from, fromRole, fromCard, ctx.mongoMe, 
             [ \value(uuid2str(ref)) | UUID ref <- refs ], ctx.myParams));
  ctx.addSteps([ *insertObjectPointer(dbName, to, toRole, toCard, \value(uuid2str(ref)) , ctx.mongoMe, ctx.myParams)
                | UUID ref <- refs ]);
}

// mongo/sql containment or xref
void compileRefAddTo(
  <DB::mongodb(), str dbName>, <DB::sql(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  {UUID ","}* refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(insertObjectPointers(dbName, from, fromRole, fromCard, ctx.mongoMe, 
             [ \value(uuid2str(ref)) | UUID ref <- refs ], ctx.myParams));
  ctx.addSteps([ *updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), ctx.sqlMe, ctx.myParams)
                | UUID ref <- refs ]);
}



/*
 * Removing from many-valued refs 
 */
 
 // sql/same sql containment
void compileRefRemoveFrom(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  {UUID ","}* refs, UpdateContext ctx
) {
  // delete each ref (we cannot orphan them)
  str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
  SQLStat theUpdate = delete(tableName(to), 
    [where([\in(column(tableName(to), typhonId(to)), [ evalExpr((Expr)`<UUID ref>`) | UUID ref <- refs ])])]);
    
  ctx.addSteps([step(dbName, sql(executeStatement(dbName, pp(theUpdate))), ctx.myParams)]);
}

// sql/other sql containment
void compileRefRemoveFrom(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  {UUID ","}* refs, UpdateContext ctx
) {
  ctx.addSteps(removeFromJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
    [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams));
    
  // NB: ownership is never many to many, so if fromRole is many, toRole cannot be
  ctx.addSteps([ *removeFromJunction(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), ctx.sqlMe, ctx.myParams)
    | UUID ref <- refs ]);
            
  ctx.addSteps(deleteManySQL(other, to, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ]));
}

// sql/mongo containment
void compileRefRemoveFrom(
  <DB::sql(), str dbName>, <DB::mongodb(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  {UUID ","}* refs, UpdateContext ctx
) {
  ctx.addSteps(removeFromJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
    [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams));
    
  ctx.addSteps(deleteManyMongo(other, to, [ \value(uuid2str(ref)) | UUID ref <- refs ], ctx.myParams));
}

// sql/same sql xref 
void compileRefRemoveFrom(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  {UUID ","}* refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(removeFromJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams));
}

// sql/other sql xref
void compileRefRemoveFrom(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  {UUID ","}* refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(removeFromJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams));
  ctx.addSteps([ removeJunction(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), ctx.sqlMe, ctx.myParams)
                 | UUID ref <- refs ]);
}

// sql/mongo xref
void compileRefRemoveFrom(
  <DB::sql(), str dbName>, <DB::mongodb(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  {UUID ","}* refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(removeFromJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams));
  ctx.addSteps(deleteManyMongo(other, to, [ \value(uuid2str(ref)) | UUID ref <- refs ], ctx.myParams));
  
}

// mongo/same mongo containment or xref
void compileRefRemoveFrom(
  <DB::mongodb(), str dbName>, <DB::mongodb(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  {UUID ","}* refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(removeObjectPointers(dbName, from, fromRole, fromCard, ctx.mongoMe, 
             [ \value(uuid2str(ref)) | UUID ref <- refs ], ctx.myParams));  
  ctx.addSteps([*removeObjectPointers(dbName, to, toRole, toCard, \value(uuid2str(ref)), [ctx.mongoMe], ctx.myParams)
                | UUID ref <- refs ]);
}

// mongo/other mongo containment or xref
void compileRefRemoveFrom(
  <DB::mongodb(), str dbName>, <DB::mongodb(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  {UUID ","}* refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(removeObjectPointers(dbName, from, fromRole, fromCard, ctx.mongoMe, 
             [ \value(uuid2str(ref)) | UUID ref <- refs ], ctx.myParams));  
  ctx.addSteps([*removeObjectPointers(other, to, toRole, toCard, \value(uuid2str(ref)), [ctx.mongoMe], ctx.myParams)
                | UUID ref <- refs ]);
}

// mongo/sql containment or xref
void compileRefRemoveFrom(
  <DB::mongodb(), str dbName>, <DB::sql(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, _>,
  {UUID ","}* refs, UpdateContext ctx
) {
  if (<to, toCard, toRole, fromRole, fromCard, from, true> <- ctx.schema.rels) {
    throw "Bad update, cannot have multiple owners.";
  }
  ctx.addSteps(removeObjectPointers(dbName, from, fromRole, fromCard, ctx.mongoMe, 
             [ \value(uuid2str(ref)) | UUID ref <- refs ], ctx.myParams));  
  ctx.addSteps([*removeFromJunction(other, from, fromRole, to, toRole, lit(evalExpr((Expr)`<UUID ref>`)), [ctx.sqlMe], ctx.myParams) 
                  | UUID ref <- refs ]);
}


