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

import IO;
import List;

alias DeleteContext = tuple[
  str entity,
  Bindings myParams,
  SQLExpr sqlMe,
  DBObject mongoMe,
  void (list[Step]) addSteps,
  Schema schema
];

Script delete2script((Request)`delete <EId e> <VId x> where <{Expr ","}+ ws>`, Schema s) {
  //s.rels = symmetricReduction(s.rels);
  
  str ent = "<e>";
  Place p = placeOf(ent, s);

  Param toBeDeleted = field(p.name, "<x>", ent, "@id");
  str myId = newParam();
  SQLExpr sqlMe = lit(Value::placeholder(name=myId));
  DBObject mongoMe = DBObject::placeholder(name=myId);
  Bindings myParams = ( myId: toBeDeleted );
  Script theScript = script([]);
  
  void addSteps(list[Step] steps) {
    theScript.steps += steps;
  }
  
  if ((Where)`where <VId _>.@id == <UUID mySelf>` := (Where)`where <{Expr ","}+ ws>`) {
    sqlMe = lit(evalExpr((Expr)`<UUID mySelf>`));
    mongoMe = \value(uuid2str(mySelf));
    myParams = ();
  }
  else {
    // first, find all id's of e things that need to be updated
    Request req = (Request)`from <EId e> <VId x> select <VId x>.@id where <{Expr ","}+ ws>`;
    addSteps(compileQuery(req, p, s));
  }
  
  
  
  DeleteContext ctx = <
    ent,
    myParams,
    sqlMe,
    mongoMe,
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
     breakOutboundPointers(p, placeOf(to, s), r, ctx);
  }

  
  deleteObject(p, ctx);
  
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
  <mongodb(), str dbName>, <mongodb(), str other:!dbName>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>, 
  DeleteContext ctx
) {
  ctx.addSteps(cascadeViaInverse(other, to, toRole, ctx.mongoMe, ctx.myParams));
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


void deleteKids(
  <sql(), str dbName>, <cassandra(), str other>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>, 
  DeleteContext ctx
) {
  // todo  
}

void deleteKids(
  <mongodb(), str dbName>, <cassandra(), str other>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>, 
  DeleteContext ctx
) {
  // todo;
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

/*
 * Break cross-ref pointers out of the deleted objects
 */
 
 void breakOutboundPointers(
  del:<sql(), str dbName>, <sql(), dbName>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>, 
  DeleteContext ctx
) {
  // automatic because of foreign keys from junction table to from
}
 

 void breakOutboundPointers(
  del:<sql(), str dbName>, <sql(), str other:!dbName>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>, 
  DeleteContext ctx
) {
  // automatic because of foreign keys from junction table to from on this db
  
  // but not for the inverse on other:
  ctx.addSteps(removeFromJunction(other, from, fromRole, to, toRole, ctx.sqlMe, ctx.myParams));
}


void breakOutboundPointers(
  del:<sql(), str dbName>, <mongodb(), str other>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>, 
  DeleteContext ctx
) {
  // automatic because of foreign keys from junction table to from on this db
  
  // but not for the inverse on other:
   ctx.addSteps(removeAllObjectPointers(other, to, toRole, toCard, ctx.mongoMe, ctx.myParams));
}


void breakOutboundPointers(
  del:<mongodb(), str dbName>, <mongodb(), dbName>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>, 
  DeleteContext ctx
) {
  // automatic because of deletion of object in the from db
  
  // but not for the inverse 
  ctx.addSteps(removeAllObjectPointers(dbName, to, toRole, toCard, ctx.mongoMe, ctx.myParams));
}
 
void breakOutboundPointers(
  del:<mongodb(), str dbName>, <mongodb(), str other:!dbName>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>, 
  DeleteContext ctx
) {
  // automatic because of deletion of object in the from db
  
  // but not for the inverse on other
  ctx.addSteps(removeAllObjectPointers(other, to, toRole, toCard, ctx.mongoMe, ctx.myParams));
}

void breakOutboundPointers(
  del:<mongodb(), str dbName>, <sql(), str other>,
  <str from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>, 
  DeleteContext ctx
) {
  // automatic because of deletion of object in the from db
  
  // but not for the inverse on sql
  ctx.addSteps(removeFromJunction(other, from, fromRole, to, toRole, ctx.sqlMe, ctx.myParams));
}
 

 
  
  