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



Script update2script((Request)`update <EId e> <VId x> where <{Expr ","}+ ws> set {<{KeyVal ","}* kvs>}`, Schema s) {
  str ent = "<e>";

  // this is needed to prevent multiple updates to "the same" junction tables etc.  
  //s.rels = symmetricReduction(s.rels);
  
  Place p = placeOf(ent, s);

  Param toBeUpdated = field(p.name, "<x>", ent, "@id");
  str myId = newParam();
  SQLExpr sqlMe = lit(Value::placeholder(name=myId));
  DBObject mongoMe = DBObject::placeholder(name=myId);
  Bindings myParams = ( myId: toBeUpdated );
  Script scr = script([]);
  
  if ((Where)`where <VId _>.@id == <UUID mySelf>` := (Where)`where <{Expr ","}+ ws>`) {
    sqlMe = lit(evalExpr((Expr)`<UUID mySelf>`));
    mongoMe = \value("<mySelf>"[1..]);
    myParams = ();
  }
  else {
    // first, find all id's of e things that need to be updated
    Request req = (Request)`from <EId e> <VId x> select <VId x>.@id where <{Expr ","}+ ws>`;
    // NB: no partitioning, compile locally.
    scr.steps = compileQuery(req, p, s);
  }
  
 
   
  switch (p) {
    case <sql(), str dbName>: {
      SQLStat stat = update(tableName(ent),
        [ Set::\set(columnName("<kv.key>", ent), SQLExpr::lit(evalExpr(kv.\value))) | KeyVal kv <- kvs, isAttr(kv, ent, s) ],
          [where([equ(column(tableName(ent), typhonId(ent)), sqlMe)])]);
      if (stat.sets != []) {
        scr.steps += [step(dbName, sql(executeStatement(dbName, pp(stat))), myParams)];
      }
      
      for ((KeyVal)`<Id fld>: <UUID ref>` <- kvs) {
        str from = "<e>";
        str fromRole = "<fld>";
        str uuid = "<ref>"[1..];

        if (<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels) {
            // this keyval is updating ref to have me as a parent/owner
            
          switch (placeOf(to, s)) {
          
            case <sql(), dbName> : {  
              // update ref's foreign key to point to sqlMe
              str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
              SQLStat theUpdate = update(tableName(to), [\set(fk, sqlMe)],
                [where([equ(column(tableName(to), typhonId(to)), lit(text(uuid)))])]);
                
              scr.steps +=  [step(dbName, sql(executeStatement(dbName, pp(theUpdate))), myParams)];
            }
            
            case <sql(), str other> : {
              // it's single ownership, so dont' insert in the junction but update.
              scr.steps +=  updateIntoJunctionSingle(p.name, from, fromRole, to, toRole, sqlMe, lit(text(uuid)), myParams);
              scr.steps +=  updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(text(uuid)), sqlMe, myParams);
            }
            
            case <mongodb(), str other>: {
              scr.steps +=  updateIntoJunctionSingle(p.name, from, fromRole, to, toRole, sqlMe, lit(text(uuid)), myParams);
              scr.steps +=  updateObjectPointer(other, to, toRole, toCard, \value(uuid), mongoMe, myParams);
            }
            
          }
        }
        
        else if (<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true> <- s.rels) {
           // this is the case that the current KeyVal pair is actually
           // setting the currently updated object as being owned by ref
           
          switch (placeOf(parent, s)) {
          
            case <sql(), dbName> : {  
              // update "my" foreign key to point to uuid
              str fk = fkName(parent, from, fromRole == "" ? parentRole : fromRole);
              SQLStat theUpdate = update(tableName(from), [\set(fk, lit(text(uuid)))],
                [where([equ(column(tableName(from), typhonId(from)), sqlMe)])]);
                
              scr.steps +=  [step(dbName, sql(executeStatement(dbName, pp(theUpdate))), myParams)];
            }
            
            case <sql(), str other> : {
              // it's single ownership, so dont' insert in the junction but update.
              scr.steps +=  updateIntoJunctionSingle(p.name, from, fromRole, parent, parentRole, lit(text(uuid)), sqlMe, myParams);
              scr.steps +=  updateIntoJunctionSingle(other, parent, parentRole, from, fromRole, lit(text(uuid)), sqlMe, myParams);
            }
            
            case <mongodb(), str other>: {
              scr.steps +=  updateIntoJunctionSingle(p.name, from, fromRole, parent, parentRole, lit(text(uuid)), sqlMe, myParams);
              scr.steps +=  updateObjectPointer(other, parent, parentRole, parentCard, \value(uuid), mongoMe, myParams);
            }
            
          }
        }
        
        // xrefs are symmetric, so both directions are done in one go. 
        else if (<from, _, fromRole, str toRole, Cardinality toCard, str to, false> <- trueCrossRefs(s.rels)) {
           // save the cross ref
           scr.steps +=  updateIntoJunctionSingle(dbName, from, fromRole, to, toRole, sqlMe, lit(text(uuid)), myParams);
           
           // and the opposite sides
           switch (placeOf(to, s)) {
             case <sql(), dbName>: {
               ; // nothing to be done, locally, the same junction table is used
               // for both directions.
             }
             case <sql(), str other>: {
               scr.steps +=  updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(text(uuid)), sqlMe, myParams);
             }
             case <mongodb(), str other>: {
               scr.steps +=  updateObjectPointer(other, to, toRole, toCard, \value(uuid), mongoMe, myParams);
             }
           }
        
        }
        else {
          throw "Cannot happen";
        } 
        
      }
      
      for ((KeyVal)`<Id fld>: [<{UUID ","}+ refs>]` <- kvs) {
        str from = "<e>";
        str fromRole = "<fld>";
        
        if (<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels) {
            // this keyval is updating each ref to have me as a parent/owner
            
          switch (placeOf(to, s)) {
          
            case <sql(), dbName> : {  
              // update each ref's foreign key to point to sqlMe
              str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
              SQLStat theUpdate = update(tableName(to), [\set(fk, sqlMe)],
                [where([\in(column(tableName(to), typhonId(to)), [ evalExpr((Expr)`<UUID ref>`) | UUID ref <- refs ])])]);
                
              scr.steps +=  [step(dbName, sql(executeStatement(dbName, pp(theUpdate))), myParams)];
            }
            
            case <sql(), str other> : {
              scr.steps +=  updateIntoJunctionMany(p.name, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ]
                 , myParams);
              // NB: ownership is never many to many, so if fromRole is many, toRole cannot be
              scr.steps +=  [ *updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), sqlMe, myParams)
                | UUID ref <- refs ];
            }
            
            case <mongodb(), str other>: {
              scr.steps +=  updateIntoJunctionMany(p.name, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], myParams);
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
           scr.steps +=  updateIntoJunctionMany(dbName, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], myParams);
           
           // and the opposite sides
           switch (placeOf(to, s)) {
             case <sql(), dbName>: {
               ; // nothing to be done, locally, the same junction table is used
               // for both directions.
             }
             case <sql(), str other>: {
               scr.steps +=  [ updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), sqlMe, myParams)
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
      } // 
      
      /*
       * Adding to many-valued collections
       */
      
      for ((KeyVal)`<Id fld> +: [<{UUID ","}+ refs>]` <- kvs) {
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
               scr.steps +=  [ insertIntoJunctionSingle(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), sqlMe, myParams)
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
      
      for ((KeyVal)`<Id fld> -: [<{UUID ","}+ refs>]` <- kvs) {
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
              scr.steps +=  removeFromJunctionMany(p.name, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ]
                 , myParams);
              // NB: ownership is never many to many, so if fromRole is many, toRole cannot be
              scr.steps +=  [ *removeFromJunctionSingle(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), sqlMe, myParams)
                | UUID ref <- refs ];
                
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
           scr.steps +=  removeFromJunctionMany(dbName, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], myParams);
           
           // and the opposite sides
           switch (placeOf(to, s)) {
             case <sql(), dbName>: {
               ; // nothing to be done, locally, the same junction table is used
               // for both directions.
             }
             case <sql(), str other>: {
               scr.steps +=  removeFromJunctionMany(p.name, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ]
                 , myParams);
               scr.steps +=  [ removeJunctionSingle(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), sqlMe, myParams)
                 | UUID ref <- refs ];
             }
             case <mongodb(), str other>: {
				scr.steps +=  removeFromJunctionMany(p.name, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ]
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
      DBObject u = object([ keyVal2prop(kv) | KeyVal kv <- kvs, !isDelta(kv) ]);
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
              steps += updateObjectPointer(dbName, to, toRole, toCard, \value(uuid), mongoMe, myParams);
            }
            
            case <mongodb(), str other> : {
              // update uuid's toRole to me, but on other db
              steps += updateObjectPointer(other, to, toRole, toCard, \value(uuid), mongoMe, myParams);
            }
            
            case <sql(), str other>: {
              steps += updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(text(uuid)), sqlMe, myParams);
            }
            
          }
        }
      }
      
      for ((KeyVal)`<Id x>: [<{UUID ","}+ refs>]` <- kvs) {
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
      
      for ((KeyVal)`<Id fld> +: [<{UUID ","}+ refs>]` <- kvs) {
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
        else if (<from, _, fromRole, str toRole, Cardinality toCard, str to, false> <- trueCrossRefs(s.rels)) {

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
                scr.steps +=  [ *insertIntoJunctionSingle(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), [sqlMe], myParams)
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
      
      for ((KeyVal)`<Id fld> -: [<{UUID ","}+ refs>]` <- kvs) {
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
        else if (<from, _, fromRole, str toRole, Cardinality toCard, str to, false> <- trueCrossRefs(s.rels)) {
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