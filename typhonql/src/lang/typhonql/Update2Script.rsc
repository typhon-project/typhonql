module lang::typhonql::Update2Script

import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::Script;
import lang::typhonql::Session;
import lang::typhonql::TDBC;
import lang::typhonql::Order;

import lang::typhonql::relational::SQL;
import lang::typhonql::relational::Util;
import lang::typhonql::relational::SQL2Text;

import lang::typhonql::mongodb::DBCollection;

import IO;
import List;
import String;

// TODO: if junction tables are symmetric, i.e. normalized name order in junctionTableName
// then we don't have to swap arguments if maintaining the inverse at outside sql db.

list[Step] updateIntoJunctionSingle(str dbName, str from, str fromRole, str to, str toRole, SQLExpr src, SQLExpr trg, Bindings params) {
  str tbl = junctionTableName(from, fromRole, to, toRole);
  return [step(dbName,
           sql(executeStatement(dbName,
             pp(delete(tbl,
                 [where([equ(columnName(tbl, junctionFkName(from, fromRole)), src),
                     equ(columnName(tbl, junctionFkName(to, toRole)), trg)])]))))),
  
          step(dbName, 
           sql(executeStatement(dbName, 
             pp(\insert(tbl
                  , [junctionFkName(from, fromRole), junctionFkName(to, toRole)]
                  , [src, trg])))), params)];
}

list[Step] updateIntoJunctionMany(str dbName, str from, str fromRole, str to, str toRole, SQLExpr src, list[SQLExpr] trgs, Bindings params) {
  str tbl = junctionTableName(from, fromRole, to, toRole);
  return [step(dbName,
           sql(executeStatement(dbName,
             pp(delete(tbl,
                 [where([equ(columnName(tbl, junctionFkName(from, fromRole)), src)])])))))]
      + 
         [ step(dbName, 
           sql(executeStatement(dbName, 
             pp(\insert(tbl
                  , [junctionFkName(from, fromRole), junctionFkName(to, toRole)]
                  , [src, trg])))), params) | SQLExpr trg <- trgs ];

}

list[Step] insertIntoJunctionMany(str dbName, str from, str fromRole, str to, str toRole, SQLExpr src, list[SQLExpr] trgs, Bindings params) {
  str tbl = junctionTableName(from, fromRole, to, toRole);
  return  [ step(dbName, 
           sql(executeStatement(dbName, 
             pp(\insert(tbl
                  , [junctionFkName(from, fromRole), junctionFkName(to, toRole)]
                  , [src, trg])))), params) | SQLExpr trg <- trgs ];
}

list[Step] insertIntoJunctionSingle(str dbName, str from, str fromRole, str to, str toRole, SQLExpr src, SQLExpr trg, Bindings params) {
  str tbl = junctionTableName(from, fromRole, to, toRole);
  return  [ step(dbName, 
           sql(executeStatement(dbName, 
             pp(\insert(tbl
                  , [junctionFkName(from, fromRole), junctionFkName(to, toRole)]
                  , [src, trg])))), params) ];
}

list[Step] updateObjectPointer(str dbName, str coll, str role, Cardinality card, DBObject subject, DBObject target, Bindings params) {
    return [
      step(dbName, mongo( 
         findAndUpdateOne(dbName, coll,
          pp(object([<"_id", subject>])), 
          pp(object([<"$set", object([<role, target>])>])))), params)
          ];
}
    
Script update2script((Request)`update <EId e> <VId x> where <{Expr ","}+ ws> set {<{KeyVal ","}* kvs>}`, Schema s) {
  str ent = "<e>";
  Place p = placeOf(ent, s);

   // first, find all id's of e things that need to be updated
  Request req = (Request)`from <EId e> <VId x> select <VId x>.@id where <{Expr ","}+ ws>`;
  
  // NB: no partitioning, compile locally.
  Script scr = script(compileQuery(req, p, s));
  
  Param toBeUpdated = field(p.name, "<x>", ent, "@id");
  str myId = newParam();
  SQLExpr sqlMe = SQLExpr::placeholder(name=myId);
  DBObject mongoMe = DBObject::placeholder(name=myId);
  Bindings myParams = ( myId: toBeUpdated );
  
  
   
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
        str fromRole = "<x>";
        str uuid = "<ref>"[1..];

        if (<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels) {
            // this keyval is updating ref to have me as a parent/owner
            
          switch (placeOf(to, s)) {
          
            case <sql(), dbName> : {  
              // update ref's foreign key to point to sqlMe
              str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
              SQLState theUpdate = update(tableName(to), [\set(fk, sqlMe)],
                [where([equ(column(tableName(to), typhonId(to)), lit(text(uuid)))])]);
                
              steps += [step(dbName, sql(executeStatement(dbName, pp(theUpdate))), myParams)];
            }
            
            case <sql(), str other> : {
              // it's single ownership, so dont' insert in the junction but update.
              steps += updateIntoJunctionSingle(p.name, from, fromRole, to, toRole, sqlMe, lit(text(uuid)), myParams);
              steps += updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(text(uuid)), sqlMe, myParams);
            }
            
            case <mongodb(), str other>: {
              steps += updateIntoJunctionSingle(p.name, from, fromRole, to, toRole, sqlMe, lit(text(uuid)), myParams);
              steps += updateObjectPointer(other, to, toRole, toCard, \value(uuid), mongoMe, myParams);
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
              SQLStat theUpdate = update(tableName(from), [\set(fk, uui)],
                [where([equ(column(tableName(from), typhonId(from)), sqlMe)])]);
                
              steps += [step(dbName, sql(executeStatement(dbName, pp(theUpdate))), myParams)];
            }
            
            case <sql(), str other> : {
              // it's single ownership, so dont' insert in the junction but update.
              steps += updateIntoJunctionSingle(p.name, from, fromRole, parent, parentRole, lit(text(uuid)), sqlMe, myParams);
              steps += updateIntoJunctionSingle(other, parent, parentRole, from, fromRole, lit(text(uuid)), sqlMe, myParams);
            }
            
            case <mongodb(), str other>: {
              steps += updateIntoJunctionSingle(p.name, from, fromRole, parent, parentRole, lit(text(uuid)), sqlMe, myParams);
              steps += updateObjectPointer(other, parent, parentRole, parentCard, \value(uuid), mongoMe, myParams);
            }
            
          }
        }
        
        // xrefs are symmetric, so both directions are done in one go. 
        else if (<from, _, fromRole, str toRole, Cardinality toCard, str to, false> <- s.rels) {
           // save the cross ref
           steps += updateIntoJunctionSingle(dbName, from, fromRole, to, toRole, sqlMe, lit(text(uuid)), myParams);
           
           // and the opposite sides
           switch (placeOf(to, s)) {
             case <sql(), dbName>: {
               ; // nothing to be done, locally, the same junction table is used
               // for both directions.
             }
             case <sql(), str other>: {
               steps += updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(text(uuid)), sqlMe, myParams);
             }
             case <mongodb(), str other>: {
               steps += updateObjectPointer(other, to, toRole, toCard, \value(uuid), mongoMe, myParams);
             }
           }
        
        }
        else {
          throw "Cannot happen";
        } 
        
      }
      
      for ((KeyVal)`<Id fld>: [<{UUID ","}+ refs>]` <- kvs) {
        str from = "<e>";
        str fromRole = "<x>";
        
        if (<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels) {
            // this keyval is updating each ref to have me as a parent/owner
            
          switch (placeOf(to, s)) {
          
            case <sql(), dbName> : {  
              // update each ref's foreign key to point to sqlMe
              str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
              SQLState theUpdate = update(tableName(to), [\set(fk, sqlMe)],
                [where([\in(column(tableName(to), typhonId(to)), [ evalExpr((Expr)`<UUID ref>`) | UUID ref <- refs ])])]);
                
              steps += [step(dbName, sql(executeStatement(dbName, pp(theUpdate))), myParams)];
            }
            
            case <sql(), str other> : {
              steps += updateIntoJunctionMany(p.name, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr(ref)) | UUID ref <- refs ]
                 , myParams);
              // NB: ownership is never many to many, so if fromRole is many, toRole cannot be
              steps += [ *updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(evalExpr(ref)), sqlMe, myParams)
                | UUID ref <- refs ];
            }
            
            case <mongodb(), str other>: {
              steps += updateIntoJunctionMany(p.name, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr(ref)) | UUID ref <- refs ], myParams);
              // NB: ownership is never many to many, so if fromRole is many, toRole cannot be
              steps += [ *updateObjectPointer(other, to, toRole, toCard, \value("<ref>"[1..]), mongoMe, myParams) 
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
        else if (<from, _, fromRole, str toRole, Cardinality toCard, str to, false> <- s.rels) {
           // save the cross ref
           steps += updateIntoJunctionMany(dbName, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], myParams);
           
           // and the opposite sides
           switch (placeOf(to, s)) {
             case <sql(), dbName>: {
               ; // nothing to be done, locally, the same junction table is used
               // for both directions.
             }
             case <sql(), str other>: {
               steps += [ updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), sqlMe, myParams)
                 | UUID ref <- refs ];
             }
             case <mongodb(), str other>: {
               // todo: deal with multiplicity correctly in updateObject Pointer
               steps += [ *updateObjectPointer(other, to, toRole, toCard, \value("<ref>"[1..]), mongoMe, myParams) 
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
        str fromRole = "<x>";
        
        if (<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels) {
            // this keyval is updating each ref to have me as a parent/owner
            
          switch (placeOf(to, s)) {
          
            case <sql(), dbName> : {  // same as above
              // update each ref's foreign key to point to sqlMe
              str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
              SQLState theUpdate = update(tableName(to), [\set(fk, sqlMe)],
                [where([\in(column(tableName(to), typhonId(to)), [ evalExpr((Expr)`<UUID ref>`) | UUID ref <- refs ])])]);
                
              steps += [step(dbName, sql(executeStatement(dbName, pp(theUpdate))), myParams)];
            }
            
            case <sql(), str other> : {
              steps += insertIntoJunctionMany(p.name, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr(ref)) | UUID ref <- refs ]
                 , myParams);
              // NB: ownership is never many to many, so if fromRole is many, toRole cannot be
              steps += [ *updateIntoJunctionSingle(other, to, toRole, from, fromRole, lit(evalExpr(ref)), sqlMe, myParams)
                | UUID ref <- refs ];
            }
            
            case <mongodb(), str other>: {
              steps += insertIntoJunctionMany(p.name, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr(ref)) | UUID ref <- refs ], myParams);
              // NB: ownership is never many to many, so if fromRole is many, toRole cannot be
              steps += [ *updateObjectPointer(other, to, toRole, toCard, \value("<ref>"[1..]), mongoMe, myParams) 
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
        else if (<from, _, fromRole, str toRole, Cardinality toCard, str to, false> <- s.rels) {
           // save the cross ref
           steps += insertIntoJunctionMany(dbName, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], myParams);
           
           // and the opposite sides
           switch (placeOf(to, s)) {
             case <sql(), dbName>: {
               ; // nothing to be done, locally, the same junction table is used
               // for both directions.
             }
             case <sql(), str other>: {
               //steps += insertIntoJunctionMany(dbName, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], myParams);
               steps += [ insertIntoJunctionSingle(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), sqlMe, myParams)
                 | UUID ref <- refs ];
             }
             case <mongodb(), str other>: {
               // todo: deal with multiplicity correctly in updateObject Pointer
               steps += [ *updateObjectPointer(other, to, toRole, toCard, \value("<ref>"[1..]), mongoMe, myParams) 
                  | UUID ref <- refs ];
             }
           }
        
        }
        else {
          throw "Cannot happen";
        } 
      }
      
      
    }
    
    case <mongodb(), str dbName>: {
      DBObject q = object([<"_id", DBObject::placeholder(name="TO_UPDATE")>]);
      DBObject u = object([ keyVal2prop(kv) | KeyVal kv <- kvs, isAttr(kv, ent, s) ]);
      if (u.props != []) {
        scr.steps += [step(dbName, mongo(findAndUpdateOne(dbName, ent, pp(q), pp(u))), ("TO_UPDATE": toBeUpdated))];
      }
    }
  
  }
  
  /*
   * what to do about nested objects? for now, we don't support them.
  */


  for ((KeyVal)`<Id fld>: <UUID ref>` <- kvs) {
    scr.steps += updateReference(p, ent, fld, ref, "TO_UPDATE", toBeUpdated, s);
  }

  for ((KeyVal)`<Id fld>: [<{UUID ","}+ refs>]` <- kvs) {
    scr.steps += updateManyReference(p, ent, fld, refs, "TO_UPDATE", toBeUpdated, s);
  }

  
  for ((KeyVal)`<Id fld> +: [<{UUID ","}+ refs>]` <- kvs) {
    scr.steps += addToManyReference(p, ent, fld, refs, "TO_UPDATE", toBeUpdated, s);
  }
  
  for ((KeyVal)`<Id fld> -: [<{UUID ","}+ refs>]` <- kvs) {
    scr.steps += removeFromManyReference(p, ent, fld, refs, "TO_UPDATE", toBeUpdated, s);
  }
  

  


}