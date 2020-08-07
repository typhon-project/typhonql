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
                    \in(column(tbl, junctionFkName(to, toRole)), [ trg.val | SQLExpr trg <- trgs ])]) ])))), params) ];
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
         findAndUpdateOne(dbName, coll,
          pp(object([<"_id", subject>])), 
          pp(object([<"$set", object([<role, target>])>])))), params)
          ];
}


list[Step] insertObjectPointer(str dbName, str coll, str role, Cardinality card, DBObject subject, DBObject trg, Bindings params) {
  if (card in {zero_many(), one_many()}) {
    return [
      step(dbName, mongo( 
         findAndUpdateOne(dbName, coll,
          pp(object([<"_id", subject>])), 
          pp(object([<"$addToSet", object([<role, array([ trg ])>])>])))), params)
          ];
  }
  return [
      step(dbName, mongo( 
         findAndUpdateOne(dbName, coll,
          pp(object([<"_id", subject>])), 
          pp(object([<"$set", object([<role, trg>])>])))), params)
          ];
  
}

list[Step] insertObjectPointers(str dbName, str coll, str role, Cardinality card, DBObject subject, list[DBObject] targets, Bindings params) {
    return [
      step(dbName, mongo( 
         findAndUpdateOne(dbName, coll,
          pp(object([<"_id", subject>])), 
          pp(object([<"$addToSet", object([<role, array([ trg | DBObject trg <- targets ])>])>])))), params)
          ];
}

list[Step] cascadeViaInverse(str dbName, str coll, str role, DBObject parent, Bindings params) {
  DBObject q = object([<role, parent>]);
  return [step(dbName, mongo(deleteMany(dbName, coll, pp(q))), params)];
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
  NodePattern n1 = nNodePattern("__n1", [], []);
  NodePattern n2 = nNodePattern("__n2", [], []);
  
  bool fromEdge = relationIsFromEdge(dbName, edge, role, s); 
  Property prop = nProperty(graphPropertyName("@id", \node), parent);
  
  if (fromEdge)
  	n1.properties += [prop];
  else 
  	n2.properties += [prop];
   
  stat = nMatchUpdate(
  	Maybe::just(nMatch([nPattern(n1, 
 			[nRelationshipPattern(nDoubleArrow(), "__r1", edge, [  ], n2)])], [])), 
 		nDelete([nVariable("__r1")]),
 		[nLit(boolean(true))]);
 		
  return [step(dbName, neo(executeNeoUpdate(dbName, neopp(stat))), params)];
}


list[Step] removeAllObjectPointers(str dbName, str coll, str role, Cardinality card, DBObject target, Bindings params) {
  if (card in {zero_many(), one_many()}) {
    return [
      step(dbName, mongo( 
         findAndUpdateMany(dbName, coll,
          pp(object([])), 
          pp(object([<"$pull", 
               object([<role, 
                 object([<"$in", array([ target ])>])>])>])))), params)
          ];
  }
  return [
      step(dbName, mongo( 
         findAndUpdateMany(dbName, coll,
          pp(object([<role, target>])), 
          pp(object([<"$set", object([<role, DBObject::null()>])>])))), params)
      ];
}

list[Step] removeObjectPointers(str dbName, str coll, str role, Cardinality card, DBObject subject, list[DBObject] targets, Bindings params) {
    return [
      step(dbName, mongo( 
         findAndUpdateOne(dbName, coll,
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
       deleteOne(dbName, coll, pp(object([<"_id", obj>])))), params)
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

/*

list[Step] cascadeToKids(str ent, Param toBeDeleted, VId x, Place p, Schema s) {
  list[Step] steps = [];
  for (<ent, _, str fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels, placeOf(to, s) != p) {
    Place kidPlace = placeOf(to, s);
    
    switch (<p, kidPlace>) {
        case <<sql(), str dbName>, <sql(), dbName>>: {
          ; // nothing to be done, kids will be deleted as a result of cascade delete
        }

        case <<sql(), str dbName>, <sql(), str dbKid>>: {
          // NB this could be done based on the id of the entity to be deleted itself
          // but breakCrossLinkInSQL now deletes based on the kid's id
          steps += breakCrossLinkInSQL(dbName, ent, SQLExpr::placeholder(name="TO_DELETE"), "TO_DELETE", field(p.name, "<x>", ent, fromRole), fromRole, to, toRole);
          SQLStat stat = delete(tableName(to), [
           where([equ(column(tableName(to), typhonId(to)), SQLExpr::placeholder(name="TO_DELETE"))])]);
        
          steps += [step(dbKid, sql(executeStatement(dbKid, pp(stat))), ("TO_DELETE": field(p.name, "<x>", ent, fromRole)))]; 
		}

        case <<sql(), str dbName>, <mongodb(), str dbKid>>: {
          // on dbName delete from junction table
          steps += breakCrossLinkInSQL(dbName, ent, SQLExpr::placeholder(name="TO_DELETE"), "TO_DELETE", field(p.name, "<x>", ent, fromRole), fromRole, to, toRole);
          
          DBObject q = object([<"_id", DBObject::placeholder(name="TO_DELETE")>]);
          steps += [step(dbKid, mongo(deleteOne(dbKid, to, pp(q))), ("TO_DELETE": field(p.name, "<x>", ent, fromRole)))];
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
          ; // nothing to be done, kids will be deleted as a result of nesting.
        }
        
        case <<mongodb(), str dbName>, <mongodb(), str dbKid>>: {
          // the refs on dbName, dissappear on delete
          // but we need to delete entities on the other mongo
          DBObject q = object([<"_id", DBObject::placeholder(name="TO_DELETE")>]);
          steps += [step(dbKid, mongo(deleteOne(dbKid, to, pp(q))), ("TO_DELETE": field(p.name, "<x>", ent, fromRole)))];
        }

        case <<mongodb(), str dbName>, <sql(), str dbKid>>: {
          // the refs on dbName, dissappear on delete
          // but we need to delete entities on dbKid sql
          SQLStat stat = delete(tableName(to), [
           where([equ(column(tableName(to, typhonId(to))), SQLExpr::placeholder(name="TO_DELETE"))])]);
        
          steps += [step(dbKid, sql(executeStatement(dbKid, pp(stat))), ("TO_DELETE": field(p.name, "<x>", ent, fromRole)))]; 
        }
    }
  }
  return steps;
}

list[Step] breakLinksWithParent(str ent, Param toBeDeleted, Place p, Schema s) {
  if (<str parent, _, str fromRole, str toRole, Cardinality toCard, ent, true> <- s.rels) {
    // NB: this assumes there's a unique owernship path
    Place parentPlace = placeOf(parent, s);
    
    switch (<parentPlace, p>) {
        case <<sql(), str dbName>, <sql(), dbName>>: {
          ; // nothing to be done, the parent link will be deleted via the foreinkey to the parent
          // when the object iself will be deleted 
        }

        case <<sql(), str dbParent>, <sql(), str dbKid>>: {
          return breakCrossLinkInSQL(dbParent, parent, SQLExpr::placeholder(name="TO_DELETE"), "TO_DELETE", toBeDeleted, fromRole, ent, toRole); 
		}

        case <<sql(), str dbParent>, <mongodb(), str dbKid>>: {
          return breakCrossLinkInSQL(dbParent, parent, SQLExpr::placeholder(name="TO_DELETE"), "TO_DELETE", toBeDeleted, fromRole, ent, toRole); 
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
          return breakCrossLinkInMongo(dbName, parent, DBObject::placeholder(name="TO_DELETE"), "TO_DELETE", toBeDeleted, fromRole, ent, toRole);
        }
        
        case <<mongodb(), str dbParent>, <mongodb(), str dbKid>>: {
          return breakCrossLinkInMongo(dbParent, parent, DBObject::placeholder(name="TO_DELETE"), "TO_DELETE", toBeDeleted, fromRole, ent, toRole);
        }

        case <<mongodb(), str dbParent>, <sql(), str dbKid>>: {
          return breakCrossLinkInMongo(dbParent, parent, DBObject::placeholder(name="TO_DELETE"), "TO_DELETE", toBeDeleted, fromRole, ent, toRole);
        }
    }
  }
  
  return [];
}

list[Step] removeFromManyReference(Place p, str ent, Id fld, {UUID ","}+ refs, str paramName, Param toBeUpdated, Schema s) {
   if (<ent, Cardinality fromCard,  str fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels, fromRole == "<fld>") {
      assert fromCard in {zero_many(), one_many()} : "Can only remove from many-valued things: <ent>.<fromRole> is not";
      
      Place targetPlace = placeOf(to, s);
      
      switch (<p, targetPlace>) {
        case <<sql(), str dbName>, <sql(), dbName>>: {
        
          
          // for each ref in refs, delete it (we cannot set the foreign key to null)
          
          str fk = fkName(ent, to, toRole == "" ? fromRole : toRole);
          list[SQLStat] stats = 
            [ delete(tableName(to),
              [where([equ(column(tableName(to), typhonId(to)), lit(evalExpr((Expr)`<UUID ref>`)))])]) | UUID ref <- refs ];
              
              
          return [step(dbName, sql(executeStatement(dbName, pp(stat))), (paramName: toBeUpdated)) 
                  | SQLStat stat <- stats ]; 
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          return [ *breakCrossLinkInSQL(myDb, ent, lit(text("<ref>"[1..])), paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return [ *breakCrossLinkInSQL(myDb, ent, lit(text("<ref>"[1..])), paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
          // Q: how to create nesting here?  --> we somehow need to disallow this (in the type checker?)
		  // if single: update me set fld to ref
		  // if multi: push/addToSet ref to fld on me
		  throw "Not yet implemented";
        }
        
        case <<mongodb(), str myDb>, <mongodb(), str dbKid>>: {
          // if single: update me set fld to ref
		  // if multi: push/addToSet ref to fld on me
		  return [ *breakCrossLinkInMongo(myDb, ent, DBObject::\value("<ref>"[1..]), paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
		  return [ *breakCrossLinkInMongo(myDb, ent, DBObject::\value("<ref>"[1..]), paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
        }
      }
    }
    // todo: require toRole to be != "" so that we have the canonical one.
    else if (<ent, _,  str fromRole, str toRole, Cardinality toCard, str to, false> <- s.rels, fromRole == "<fld>") {
      // a crossref.
      Place targetPlace = placeof(to, s);
      switch (<p, targetPlace>) {
        case <<sql(), str myDb>, <sql(), dbName>>: {
          return [ *breakCrossLinkInSQL(myDb, ent, lit(text("<ref>"[1..])), paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          return [ *breakCrossLinkInSQL(myDb, ent, lit(text("<ref>"[1..])), paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return [ *breakCrossLinkInSQL(myDb, ent, lit(text("<ref>"[1..])), paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
		  return [ *breakCrossLinkInMongo(myDb, ent, DBObject::\value("<ref>"[1..]), paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
        }
        
        case <<mongodb(), str myDb>, <mongodb(), str dbKid>>: {
		  return [ *breakCrossLinkInMongo(myDb, ent, DBObject::\value("<ref>"[1..]), paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
		  return [ *breakCrossLinkInMongo(myDb, ent, DBObject::\value("<ref>"[1..]), paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
        }
      }
    }
    else {
     throw "Could not find field <fld> in schema for <ent>";
    }
}


list[Step] addToManyReference(Place p, str ent, Id fld, {UUID ","}+ refs, str paramName, Param toBeUpdated, Schema s) {
  if (<ent, Cardinality fromCard,  str fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels, fromRole == "<fld>") {
      assert fromCard in {zero_many(), one_many()}: "Can only add to many-valued things: <ent>.<fromRole> is not";
      
      Place targetPlace = placeOf(to, s);
      
      switch (<p, targetPlace>) {
        case <<sql(), str dbName>, <sql(), dbName>>: {
        
          
          // for each ref in refs, make it point to "me"
          // (the diff with updateManyReference, is we don't delete existing links)
          
          str fk = fkName(ent, to, toRole == "" ? fromRole : toRole);
          list[SQLStat] stats = 
            [ update(tableName(to),
              [ \set(columnName(tableName(to), fk), SQLExpr::placeholder(name=paramName)) ],
              [where([equ(column(tableName(to), typhonId(to)), lit(evalExpr((Expr)`<UUID ref>`)))])]) | UUID ref <- refs ];
              
              
          return [step(dbName, sql(executeStatement(dbName, pp(stat))), (paramName: toBeUpdated)) 
                  | SQLStat stat <- stats ]; 
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          //createCrossLinkInSQL(str dbName, str parent, str uuid, str fromRole, str to, str toRole)
          return [ *createCrossLinkInSQL(myDb, ent, "<ref>"[1..], paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return [ *createCrossLinkInSQL(myDb, ent, "<ref>"[1..], paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
          // Q: how to create nesting here?  --> we somehow need to disallow this (in the type checker?)
		  // if single: update me set fld to ref
		  // if multi: push/addToSet ref to fld on me
		  ;            
        }
        
        case <<mongodb(), str myDb>, <mongodb(), str dbKid>>: {
          // if single: update me set fld to ref
		  // if multi: push/addToSet ref to fld on me
		  //list[Step] createCrossLinkInMongo(str dbName, str parent, str uuid, str fromRole, Cardinality toCard) {
		  return [ *createCrossLinkInMongo(myDb, ent, "<ref>"[1..], paramName, toBeUpdated, fromRole, toCard, toBeUpdated) | UUID ref <- refs ];
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
		  return [ *createCrossLinkInMongo(myDb, ent, "<ref>"[1..], paramName, toBeUpdated, fromRole, toCard, toBeUpdated) | UUID ref <- refs ];
        }
      }
    }
    else if (<ent, Cardinality fromCard,  str fromRole, str toRole, Cardinality toCard, str to, false> <- s.rels, fromRole == "<fld>") {
      // a crossref.
      assert fromCard in {zero_many(), one_many()}: "Can only remove from many-valued things: <ent>.<fromRole> is not";
      
      Place targetPlace = placeof(to, s);
      switch (<p, targetPlace>) {
        case <<sql(), str myDb>, <sql(), dbName>>: {
          return [ *createCrossLinkInSQL(myDb, ent, "<ref>"[1..], paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          return [ *createCrossLinkInSQL(myDb, ent, "<ref>"[1..], paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return [ *createCrossLinkInSQL(myDb, ent, "<ref>"[1..], paramName, toBeUpdated, fromRole, to, toRole) | UUID ref <- refs ];
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
          return [ *createCrossLinkInMongo(myDb, ent, "<ref>"[1..], paramName, toBeUpdated, fromRole, toCard, toBeUpdated) | UUID ref <- refs ];            
        }
        
        case <<mongodb(), str myDb>, <mongodb(), str dbKid>>: {
		  return [ *createCrossLinkInMongo(myDb, ent, "<ref>"[1..], paramName, toBeUpdated, fromRole, toCard, toBeUpdated) | UUID ref <- refs ];
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
          return [ *createCrossLinkInMongo(myDb, ent, "<ref>"[1..], paramName, toBeUpdated, fromRole, toCard, toBeUpdated) | UUID ref <- refs ];
        }
      }
    }
    else {
     throw "Could not find field <fld> in schema for <ent>";
    }
}

list[Step] updateManyReference(Place p, str ent, Id fld, {UUID ","}+ refs, str paramName, Param toBeUpdated, Schema s) {
  if (<ent, Cardinality fromCard,  str fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels, fromRole == "<fld>") {
      assert fromCard in {zero_many(), one_many()} : "Can only remove from many-valued things: <ent>.<fromRole> is not";
      
      Place targetPlace = placeOf(to, s);
      
      switch (<p, targetPlace>) {
        case <<sql(), str dbName>, <sql(), dbName>>: {
        
          // for each ref in refs, make it point to "me"
          // then delete all kids pointing to me *not in* refs
        
          str fk = fkName(ent, to, toRole == "" ? fromRole : toRole);
          list[SQLStat] stats = 
            //[
            //  update(tableName(to),
            //    [ \set(columnName(tableName(to), fk), lit(null())) ],
            //    [where([equ(column(tableName(to), fk), SQLExpr::placeholder(name="TO_UPDATE"))])])
            //] +
            [ update(tableName(to),
              [ \set(columnName(tableName(to), fk), SQLExpr::placeholder(name=paramName)) ],
              [where([equ(column(tableName(to), typhonId(to)), lit(evalExpr((Expr)`<UUID ref>`)))])]) | UUID ref <- refs ]
            + [
              delete(tableName(to), [
                where([ notIn(column(tableName(to), fk), [ evalExpr((Expr)`<UUID ref>`) | UUID ref <- refs ]) ])
              ])
            ] 
            ;
              
              
          return [step(dbName, sql(executeStatement(dbName, pp(stat))), (paramName: toBeUpdated)) 
                  | SQLStat stat <- stats ]; 
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          return updateSQLParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, paramName, toBeUpdated);
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return updateSQLParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, paramName, toBeUpdated);
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
          // Q: how to create nesting here?  --> we somehow need to disallow this (in the type checker?)
		  // if single: update me set fld to ref
		  // if multi: push/addToSet ref to fld on me
		  ;            
        }
        
        case <<mongodb(), str myDb>, <mongodb(), str dbKid>>: {
          // if single: update me set fld to ref
		  // if multi: push/addToSet ref to fld on me
		  return updateMongoParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, paramName, toBeUpdated);
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
          return updateMongoParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, paramName, toBeUpdated);
        }
      }
    }
    else if (<ent, _,  str fromRole, str toRole, Cardinality toCard, str to, false> <- s.rels, fromRole == "<fld>") {
      // a crossref.
      Place targetPlace = placeof(to, s);
      switch (<p, targetPlace>) {
        case <<sql(), str myDb>, <sql(), dbName>>: {
          return updateSQLParent(myDb, ent, fromRole, to, toRole, toCard, refs, paramName, toBeUpdated);
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          return updateSQLParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, paramName, toBeUpdated);
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return updateSQLParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, paramName, toBeUpdated);
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
          return updateMongoParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, paramName, toBeUpdated);            
        }
        
        case <<mongodb(), str myDb>, <mongodb(), str dbKid>>: {
		  return updateMongoParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, paramName, toBeUpdated);
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
          return updateMongoParentManyKids(myDb, ent, fromRole, to, toRole, toCard, refs, paramName, toBeUpdated);
        }
      }
    }
    else {
     throw "Could not find field <fld> in schema for <ent>";
    }
}

list[Step] updateReference(Place p, str ent, Id fld, UUID ref, str paramName, Param toBeUpdated, Schema s) {
    if (<ent, _,  str fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels, fromRole == "<fld>") {
      Place targetPlace = placeof(to, s);
      switch (<p, targetPlace>) {
        case <<sql(), str dbName>, <sql(), dbName>>: {
          str fk = fkName(ent, to, toRole == "" ? fromRole : toRole);
          SQLStat stat = update(tableName(to),
              [ \set(columnName(tableName(to), fk), SQLExpr::placeholder(name=paramName)) ],
              [where([equ(column(tableName(to), typhonId(to)), lit(evalExpr((Expr)`<UUID ref>`)))])]);
          return [step(dbName, sql(executeStatement(dbName, pp(stat))), (paramName: toBeUpdated))]; 
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          return updateSQLParent(myDb, ent, fromRole, to, toRole, toCard, ref, paramName, toBeUpdated);
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return updateSQLParent(myDb, ent, fromRole, to, toRole, toCard, ref, paramName, toBeUpdated);
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
          // Q: how to create nesting here?  --> we somehow need to disallow this (in the type checker?)
		  // if single: update me set fld to ref
		  // if multi: push/addToSet ref to fld on me
		  ;            
        }
        
        case <<mongodb(), str myDb>, <mongodb(), str dbKid>>: {
          // if single: update me set fld to ref
		  // if multi: push/addToSet ref to fld on me
		  return updateMongoParent(myDb, ent, fromRole, to, toRole, toCard, ref, paramName, toBeUpdated);
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
          return updateMongoParent(myDb, ent, fromRole, to, toRole, toCard, ref, paramName, toBeUpdated);
        }
      }
    }
    else if (<ent, _,  str fromRole, str toRole, Cardinality toCard, str to, false> <- s.rels, fromRole == "<fld>") {
      // a crossref.
      Place targetPlace = placeof(to, s);
      switch (<p, targetPlace>) {
        case <<sql(), str myDb>, <sql(), dbName>>: {
           return updateSQLParent(myDb, ent, fromRole, to, toRole, toCard, ref, paramName, toBeUpdated);
        }

        case <<sql(), str myDb>, <sql(), str dbKid>>: {
          return updateSQLParent(myDb, ent, fromRole, to, toRole, toCard, ref, paramName, toBeUpdated);
		}

        case <<sql(), str myDb>, <mongodb(), str dbKid>>: {
          return updateSQLParent(myDb, ent, fromRole, to, toRole, toCard, ref, paramName, toBeUpdated);
		}
        
        case <<mongodb(), str dbName>, <mongodb(), dbName>>: {
          return updateMongoParent(myDb, ent, fromRole, to, toRole, toCard, ref, paramName, toBeUpdated);            
        }
        
        case <<mongodb(), str myDb>, <mongodb(), str dbKid>>: {
		  return updateMongoParent(myDb, ent, fromRole, to, toRole, toCard, ref, paramName, toBeUpdated);
        }

        case <<mongodb(), str myDb>, <sql(), str dbKid>>: {
          return updateMongoParent(myDb, ent, fromRole, to, toRole, toCard, ref, paramName, toBeUpdated);
        }
      }
    }
    else {
     throw "Could not find field <fld> in schema for <ent>";
    }
}

list[Step] updateSQLParentManyKids(str dbName, str ent, str fromRole, str to, str toRole, Cardinality toCard, {UUID ","}+ refs, str paramName, Param toBeUpdated) {
  str parentFk = junctionFkName(ent, fromRole);
  str kidFk = junctionFkName(to, toRole);
  str fkTbl = junctionTableName(ent, fromRole, to, toRole);
  
  list[SQLStat] stats = [
        // first delete any old ones (kids/targets)
        delete(fkTbl, [where([
          equ(column(fkTbl, parentFk), SQLExpr::placeholder(name=paramName))])
        ]),
        // then insert it for each ref
        *[
          \insert(fkTbl, [parentFk, kidFk], [Value::placeholder(name=paramName),  evalExpr((Expr)`<UUID ref>`)])
            | UUID ref <- refs ]
      ];
  
  return [step(dbName, sql(executeStatement(dbName, pp(stat))), (paramName: toBeUpdated)) | SQLStat stat <- stats ];
}


list[Step] updateSQLParent(str dbName, str ent, str fromRole, str to, str toRole, Cardinality toCard, UUID ref, str paramName, Param toBeUpdated) {
  // this code is very similar to createCrossLInk..., but that function
  // assumes it is a *new* link.
  str parentFk = junctionFkName(ent, fromRole);
  str kidFk = junctionFkName(to, toRole);
  str fkTbl = junctionTableName(ent, fromRole, to, toRole);
  
  // update junctiontable so that fk points to me for ref
  
  list[SQLStat] stats = [];
  if (toCard in {one_many(), zero_many()}) {
      stats = [
        // NB: we have to do delete + insert, because we can't use
        // update as it presumes that it is already there;
        // in this case: if it's not, delete will be a no-op.
        // first delete the old one, if any
        delete(fkTbl, [where([
          equ(column(fkTbl, parentFk), SQLExpr::placeholder(name=paramName)),
          equ(column(fkTbl, kidFk), lit(evalExpr((Expr)`<UUID ref>`)))])
        ]),
        // then insert it
        \insert(fkTbl, [parentFk, kidFk], [Value::placeholder(name=paramName),  evalExpr((Expr)`<UUID ref>`)])
      ];
  }
  else {
    stats = [
      // first delete *any* old one, if any
      delete(fkTbl, [where([equ(column(fkTbl, parentFk), SQLExpr::placeholder(name=paramName))])]),
      // then insert it
      \insert(fkTbl, [parentFk, kidFk], [Value::placeholder(name=paramName),  evalExpr((Expr)`<UUID ref>`)])
    ];
  }
	          
  return [step(dbName, sql(executeStatement(dbName, pp(stat))), (paramName: toBeUpdated)) | SQLStat stat <- stats ];
}

list[Step] updateMongoParentManyKids(str dbName, str ent, str fromRole, str to, str toRole, Cardinality toCard, {UUID ","}+ refs, str param, Param toBeUpdated) {
  DBObject q = object([<"_id", DBObject::placeholder(name=param)>]); // unfortunately we cannot reuse expr2obj here...
  
  DBObject makeKid(UUID ref) = \value("<ref>"[1..]);
  
  DBObject u = object([<"$set", object([<fromRole, array([ makeKid(ref) | UUID ref <- refs ])>])>]);
  
  return [step(dbName, mongo(findAndUpdateOne(dbName, parent, pp(q), pp(u))), (param: toBeUpdated))];
}

list[Step] updateMongoParent(str dbName, str ent, str fromRole, str to, str toRole, Cardinality toCard, UUID ref, str param, Param toBeUpdated) { 
  DBObject q = object([<"_id", DBObject::placeholder(name=param)>]); // unfortunately we cannot reuse expr2obj here...
  DBObject kid = \value("<ref>"[1..]);
  DBObject u = object([<"$set", object([<fromRole, kid>])>]);
  if (toCard in {one_many(), zero_many()}) {
    u = object([<"$addToSet", object([<fromRole, kid>])>]);
  }
  return [step(dbName, mongo(findAndUpdateOne(dbName, parent, pp(q), pp(u))), (param: toBeUpdated))];
}


list[Step] breakCrossLinkInSQL(str dbName, str parent, SQLExpr kid, str param, Param kidField, str fromRole, str to, str toRole) {
  SQLStat parentStat = 
    \delete(junctionTableName(parent, fromRole, to, toRole),[
      where([
        equ(column(junctionTableName(parent, fromRole, to, toRole), junctionFkName(parent, fromRole)), kid)
      ])]);
   return [step(dbName, sql(executeStatement(dbName, pp(parentStat))), (param: kidField))];         
}

list[Step] breakCrossLinkInMongo(str dbName, str parent, DBObject kid, str kidParam, Param kidField, str fromRole, str to, str toRole) {
  // findAndUpdateOne({}, {$pull: {fromRole: <kidParam>}});
  DBObject q = object([]);
  DBObject u = object([<"$pull", object([<fromRole, kid>])>]);
  return [step(dbName, mongo(findAndUpdateOne(dbName, parent, pp(q), pp(u))), (kidParam: kidField))];
}


list[Step] createCrossLinkInSQL(str dbName, str parent, str uuid, SQLExpr kid, Bindings params, str fromRole, str to, str toRole) {
  SQLStat parentStat = 
    \insert(junctionTableName(parent, fromRole, to, toRole)
            , [junctionFkName(to, toRole), junctionFkName(parent, fromRole)]
            , [kid, lit(text(uuid))]);
   return [step(dbName, sql(executeStatement(dbName, pp(parentStat))), params)];         
}


list[Step] createCrossLinkInMongo(str dbName, str parent, str uuid, str kidParam, Param kidValue, str fromRole, Cardinality toCard) {
  DBObject q = object([<"_id", \value(uuid)>]);
  DBObject u = object([<"$set", object([<fromRole, DBObject::placeholder(name=kidParam)>])>]);
  if (toCard in {one_many(), zero_many()}) {
    u = object([<"$addToSet", object([<fromRole, DBObject::placeholder(name=kidParam)>])>]);
  }
  return [step(dbName, mongo(findAndUpdateOne(dbName, parent, pp(q), pp(u))), (kidParam: kidValue))];
}
*/
