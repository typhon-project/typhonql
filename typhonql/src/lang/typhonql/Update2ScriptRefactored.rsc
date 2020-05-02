module lang::typhonql::Update2ScriptRefactored

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
    Step st = step(p.name, mongo(findAndUpdateOne(p.name, ent, pp(theFiler), pp(theObject))), myParams);
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
  });
}

void compileRefSet(
  <DB::sql(), str dbName>, <DB::sql(), dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  UUID ref, UpdateContext ctx
) {
  // update ref's foreign key to point to sqlMe
  str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
  SQLStat theUpdate = update(tableName(to), [\set(fk, ctx.sqlMe)],
    [where([equ(column(tableName(to), typhonId(to)), lit(text(uuid2str(ref))))])]);
  addSteps([step(dbName, sql(executeStatement(dbName, pp(theUpdate))), ctx.myParams)]);
}
 
void compileRefSet(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
  UUID ref, UpdateContext ctx
) {
   // it's single ownership, so dont' insert in the junction but update.
  ctx.addSteps(updateIntoJunctionSingle(dbName, from, fromRole, to, toRole, ctx.sqlMe, lit(text(uuid2str(ref))), ctx.myParams));
  ctx.addSteps(updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(text(uuid2str(ref))), ctx.sqlMe, ctx.myParams));
}
 
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

void compileRefSet(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole, 
  Rel r:<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true>,
  UUID ref, UpdateContext ctx
) {
  // it's single ownership, so dont' insert in the junction but update.
  ctx.addSteps(updateIntoJunctionSingle(dbName, from, fromRole, parent, parentRole, lit(text(uuid2str(ref))), ctx.sqlMe, ctx.myParams));
  ctx.addSteps(updateIntoJunctionSingle(other, parent, parentRole, from, fromRole, lit(text(uuid2str(ref))), ctx.sqlMe, ctx.myParams));
}

void compileRefSet(
  <DB::sql(), str dbName>, <DB::mongodb(), str other>, str from, str fromRole, 
  Rel r:<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true>,
  UUID ref, UpdateContext ctx
) {
  ctx.addSteps(updateIntoJunctionSingle(dbName, from, fromRole, parent, parentRole, lit(text(uuid2str(ref))), ctx.sqlMe, ctx.myParams));
  ctx.addSteps(updateObjectPointer(other, parent, parentRole, parentCard, \value(uuid2str(ref)), ctx.mongoMe, ctx.myParams));
}


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

void compileRefSet(
  <DB::sql(), str dbName>, <DB::sql(), str other:!dbName>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  UUID ref, UpdateContext ctx
) {
  ctx.addSteps(updateIntoJunctionSingle(dbName, from, fromRole, to, toRole, ctx.sqlMe, lit(text(uuid2str(ref))), ctx.myParams));
  ctx.addSteps(updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(text(uuid2str(ref))), ctx.sqlMe, ctx.myParams));
}

void compileRefSet(
  <DB::sql(), str dbName>, <DB::mongodb(), str other>, str from, str fromRole, 
  Rel r:<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
  UUID ref, UpdateContext ctx
) {
  ctx.addSteps(updateIntoJunctionSingle(dbName, from, fromRole, to, toRole, ctx.sqlMe, lit(text(uuid2str(ref))), ctx.myParams));
  addSteps(updateObjectPointer(other, to, toRole, toCard, \value(uuid2str(ref)), ctx.mongoMe, ctx.myParams));
}

/* 
 * Many-valued set
 */

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

/*
 * Adding to many-valued collections
 */
 
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


void old () {
   
  switch (p) {
    case <sql(), str dbName>: {
      for ((KeyVal)`<Id fld>: <UUID ref>` <- kvs) {
        ;
      }
      
      
      /*
       * Adding to many-valued collections
       */
      
      for ((KeyVal)`<Id fld> +: [<{UUID ","}* refs>]` <- kvs) {
        str from = "<e>";
        str fromRole = "<fld>";
        
        if (<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels) {
            // this keyval is updating each ref to have me as a parent/owner
            
          switch (placeOf(to, s)) {
          
            case <sql(), dbName> : {  // same as above
              // update each ref's foreign key to point to sqlMe
              str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
              SQLStat theUpdate = update(tableName(to), [\set(fk, sqlMe)],
                [where([\in(column(tableName(to), typhonId(to)), [ evalExpr((Expr)`<UUID ref>`) | UUID ref <- refs ])])]);
                
              scr.steps +=  [step(dbName, sql(executeStatement(dbName, pp(theUpdate))), myParams)];
            }
            
            case <sql(), str other> : {
              scr.steps +=  insertIntoJunction(p.name, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ]
                 , myParams);
              // NB: ownership is never many to many, so if fromRole is many, toRole cannot be
              scr.steps +=  [ *updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), sqlMe, myParams)
                | UUID ref <- refs ];
            }
            
            case <mongodb(), str other>: {
              scr.steps +=  insertIntoJunction(p.name, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], myParams);
              // NB: ownership is never many to many, so if fromRole is many, toRole cannot be
              scr.steps +=  [ *updateObjectPointer(other, to, toRole, toCard, \value("<ref>"[1..]), mongoMe, myParams) 
                  | UUID ref <- refs ];
            }
            
          }
        }
        
        else if (<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true> <- s.rels) {
           // this is the case that the current KeyVal pair is actually
           // setting the currently updated object as being owned by each ref (which should not be possible)
           throw "Bad update: an object cannot have many parents  <refs>";
        }
        // xrefs are symmetric, so both directions are done in one go. 
        else if (<from, _, fromRole, str toRole, Cardinality toCard, str to, false> <- trueCrossRefs(s.rels)) {
           // save the cross ref
           scr.steps +=  insertIntoJunction(dbName, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], myParams);
           
           // and the opposite sides
           switch (placeOf(to, s)) {
             case <sql(), dbName>: {
               ; // nothing to be done, locally, the same junction table is used
               // for both directions.
             }
             case <sql(), str other>: {
               //scr.steps +=  insertIntoJunctionMany(dbName, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], myParams);
               scr.steps +=  [ *insertIntoJunctionSingle(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), sqlMe, myParams)
                 | UUID ref <- refs ];
             }
             case <mongodb(), str other>: {
               // todo: deal with multiplicity correctly in updateObject Pointer
               scr.steps +=  [ *updateObjectPointer(other, to, toRole, toCard, \value("<ref>"[1..]), mongoMe, myParams) 
                  | UUID ref <- refs ];
             }
           }
        
        }
        else {
          throw "Cannot happen";
        } 
      }
      
      /*
       * Removing from many-valued collections
       */
      
      for ((KeyVal)`<Id fld> -: [<{UUID ","}* refs>]` <- kvs) {
        str from = "<e>";
        str fromRole = "<fld>";
        
        if (<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels) {
           // this keyval is for each ref removing me as a parent/owner
            
          switch (placeOf(to, s)) {
          
            case <sql(), dbName> : {  // same as above
              // delete each ref (we cannot orphan them)
              str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
              SQLStat theUpdate = delete(tableName(to), 
                [where([\in(column(tableName(to), typhonId(to)), [ evalExpr((Expr)`<UUID ref>`) | UUID ref <- refs ])])]);
                
              scr.steps +=  [step(dbName, sql(executeStatement(dbName, pp(theUpdate))), myParams)];
            }
            
            case <sql(), str other> : {
              scr.steps +=  removeFromJunction(p.name, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ]
                 , myParams);
              // NB: ownership is never many to many, so if fromRole is many, toRole cannot be
              scr.steps +=  [ *removeFromJunction(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), sqlMe, myParams)
                | UUID ref <- refs ];
                
              // SQLStat stat = delete(tableName(ent),
          // [where([equ(column(tableName(ent), typhonId(ent)), sqlMe)])]);
          
       // scr.steps += [step(dbName, sql(executeStatement(dbName, pp(stat))), myParams) ]; 
              scr.steps +=  deleteManySQL(other, to, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ]);
            }
            
            case <mongodb(), str other>: {
              scr.steps +=  removeFromJunction(p.name, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], myParams);
              scr.steps +=  deleteManyMongo(other, to, [ \value("<ref>"[1..]) | UUID ref <- refs ], myParams);
            }
            
          }
        }
        
        else if (<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true> <- s.rels) {
           // this is the case that the current KeyVal pair is actually
           // removing owernship for the currently updated object as not being owned anymore by each ref (which should not be possible)
           throw "Bad update: an object cannot have many parents  <refs>";
        }
        // xrefs are symmetric, so both directions are done in one go. 
        else if (<from, _, fromRole, str toRole, Cardinality toCard, str to, false> <- trueCrossRefs(s.rels)) {
           // save the cross ref
           scr.steps +=  removeFromJunction(dbName, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], myParams);
           
           // and the opposite sides
           switch (placeOf(to, s)) {
             case <sql(), dbName>: {
               ; // nothing to be done, locally, the same junction table is used
               // for both directions.
             }
             case <sql(), str other>: {
               scr.steps +=  removeFromJunction(p.name, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ]
                 , myParams);
               scr.steps +=  [ removeJunction(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), sqlMe, myParams)
                 | UUID ref <- refs ];
             }
             case <mongodb(), str other>: {
				scr.steps +=  removeFromJunction(p.name, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ]
                 , myParams);
                scr.steps +=  deleteManyMongo(other, to, [ \value("<ref>"[1..]) | UUID ref <- refs ], myParams);
             }
           }
        
        }
        else {
          throw "Cannot happen";
        } 
      }
      
    }
    
    case <mongodb(), str dbName>: {
      DBObject q = object([<"_id", mongoMe>]);
      DBObject u = object([ <"$set", object([keyVal2prop(kv)])> | KeyVal kv <- kvs, !isDelta(kv) ]);
      if (u.props != []) {
        scr.steps += [step(dbName, mongo(findAndUpdateOne(dbName, ent, pp(q), pp(u))), myParams)];
      }
      
      // refs/ (local) containment are direct, but we need to update the other direction.
      
      for ((KeyVal)`<Id x>: <UUID ref>` <- kvs) {
        str from = "<e>";
        str fromRole = "<x>";
        str uuid = "<ref>"[1..];

        if (<from, _, fromRole, str toRole, Cardinality toCard, str to, _> <- s.rels) {
          switch (placeOf(to, s)) {
          
            case <mongodb(), dbName> : {  
              // update uuid's toRole to me
              scr.steps += updateObjectPointer(dbName, to, toRole, toCard, \value(uuid), mongoMe, myParams);
            }
            
            case <mongodb(), str other> : {
              // update uuid's toRole to me, but on other db
              scr.steps += updateObjectPointer(other, to, toRole, toCard, \value(uuid), mongoMe, myParams);
            }
            
            case <sql(), str other>: {
              scr.steps += updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(text(uuid)), sqlMe, myParams);
            }
            
          }
        }
      }
      
      for ((KeyVal)`<Id x>: [<{UUID ","}* refs>]` <- kvs) {
        str from = "<e>";
        str fromRole = "<x>";

        // only update the inverses 
        if (<from, _, fromRole, str toRole, Cardinality toCard, str to, _> <- s.rels) {
          switch (placeOf(to, s)) {
          
            case <mongodb(), dbName> : {  
              scr.steps += [ *updateObjectPointer(dbName, to, toRole, toCard, \value("<ref>"[1..]) , mongoMe, myParams)
                | UUID ref <- refs ];
            }
            
            case <mongodb(), str other> : {
              scr.steps += [ *updateObjectPointer(dbName, to, toRole, toCard, \value("<ref>"[1..]) , mongoMe, myParams)
                | UUID ref <- refs ];
              
              // we need to delete all Mongo objects in role that have a ref to mongome via toRole
              // whose _id is not in refs.
              DBObject q = object([<"_id", object([<"$nin", array([ \value("<ref>"[1..]) | UUID ref <- refs ])>])>
                 , <toRole, mongoMe>]);
              scr.steps += [ 
                step(other, mongo(deleteMany(other, to, pp(q))), myParams)];
            }
            
            case <sql(), str other>: {
              scr.steps += [ *updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), sqlMe, myParams)
                | UUID ref <- refs ];
            }
            
          }
        }
      }
      
      
      /*
       * Adding to many-valued collections
       */
      
      for ((KeyVal)`<Id fld> +: [<{UUID ","}* refs>]` <- kvs) {
        str from = "<e>";
        str fromRole = "<fld>";
        
        
        if (<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels) {
        
          scr.steps += insertObjectPointers(dbName, from, fromRole, fromCard, mongoMe, 
             [ \value("<ref>"[1..]) | UUID ref <- refs ], myParams);
            
          switch (placeOf(to, s)) {
          
            case <mongodb(), dbName> : {  // same as above
              scr.steps += [ *updateObjectPointer(dbName, to, toRole, toCard, \value("<ref>"[1..]) , mongoMe, myParams)
                | UUID ref <- refs ];
            }
            
            case <mongodb(), str other>: {
              scr.steps +=  [ *updateObjectPointer(other, to, toRole, toCard, \value("<ref>"[1..]), mongoMe, myParams) 
                  | UUID ref <- refs ];
            }
            
            case <sql(), str other> : {
              scr.steps +=  [ *updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), sqlMe, myParams)
                | UUID ref <- refs ];
            }
            
           
            
          }
        }
        
        else if (<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true> <- s.rels) {
           // this is the case that the current KeyVal pair is actually
           // setting the currently updated object as being owned by each ref (which should not be possible)
           throw "Bad update: an object cannot have many parents  <refs>";
        }
        // xrefs are symmetric, so both directions are done in one go. 
        else if (<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false> <- trueCrossRefs(s.rels)) {

           scr.steps += insertObjectPointers(dbName, from, fromRole, fromCard, mongoMe, 
               [ \value("<ref>"[1..]) | UUID ref <- refs ], myParams);

           switch (placeOf(to, s)) {
             case <mongodb(), dbName>: {
                scr.steps += [ *insertObjectPointer(dbName, to, toRole, toCard, \value("<ref>"[1..]) , mongoMe, myParams)
                | UUID ref <- refs ];
             }
             case <mongodb(), str other>: {
                scr.steps += [ *insertObjectPointer(dbName, to, toRole, toCard, \value("<ref>"[1..]) , mongoMe, myParams)
                | UUID ref <- refs ];
             }
             case <sql(), str other>: {
                scr.steps +=  [ *insertIntoJunction(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), [sqlMe], myParams)
                | UUID ref <- refs ];
             
             }
           }
        
        }
        else {
          throw "Cannot happen";
        } 
      }
      
      /*
       * Removing from many-valued collections
       */
      
      for ((KeyVal)`<Id fld> -: [<{UUID ","}* refs>]` <- kvs) {
        str from = "<e>";
        str fromRole = "<fld>";
        
        if (<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels) {
           // this keyval is for each ref removing me as a parent/owner
            
          scr.steps += removeObjectPointers(dbName, from, fromRole, fromCard, mongoMe, 
             [ \value("<ref>"[1..]) | UUID ref <- refs ], myParams);  
            
          switch (placeOf(to, s)) {
          
            case <mongodb(), dbName> : {  
              scr.steps = [*removeObjectPointers(dbName, to, toRole, toCard, \value("<ref>"[1..]), [mongoMe], myParams)
                | UUID ref <- refs ];
            }
            
            case <mongodb(), str other> : {  
              scr.steps = [*removeObjectPointers(dbName, to, toRole, toCard, \value("<ref>"[1..]), [mongoMe], myParams)
                | UUID ref <- refs ];
            }
            
            
            case <sql(), str other> : {
              scr.steps +=  [*removeFromJunction(other, from, fromRole, to, toRole, lit(evalExpr((Expr)`<UUID ref>`)), [sqlMe], myParams) 
                  | UUID ref <- refs ];
            }
            
          }
        }
        
        else if (<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true> <- s.rels) {
           // this is the case that the current KeyVal pair is actually
           // removing owernship for the currently updated object as not being owned anymore by each ref (which should not be possible)
           throw "Bad update: an object cannot have many parents  <refs>";
        }
        else if (<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false> <- trueCrossRefs(s.rels)) {
           scr.steps += removeObjectPointers(dbName, from, fromRole, fromCard, mongoMe, 
             [ \value("<ref>"[1..]) | UUID ref <- refs ], myParams);  
            
           switch (placeOf(to, s)) {
          
            case <mongodb(), dbName> : {  
              scr.steps = [*removeObjectPointers(dbName, to, toRole, toCard, \value("<ref>"[1..]), [mongoMe], myParams)
                | UUID ref <- refs ];
            }
            
            case <mongodb(), str other> : {  
              scr.steps = [*removeObjectPointers(dbName, to, toRole, toCard, \value("<ref>"[1..]), [mongoMe], myParams)
                | UUID ref <- refs ];
            }
            
            
            case <sql(), str other> : {
              scr.steps +=  [*removeFromJunction(other, from, fromRole, to, toRole, lit(evalExpr((Expr)`<UUID ref>`)), [sqlMe], myParams) 
                  | UUID ref <- refs ];
            }
            
          }
        
        }
        else {
          throw "Cannot happen";
        } 
      }
      
      
    }
  
  }
  
  /*
   * what to do about nested objects? for now, we don't support them.
   * we could insert them directly, but what happens with all the inverse management
   * for the implicitly insert entities??
  */


  return scr;
 

  


}