module lang::typhonql::Insert2ScriptRefactored

import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::Script;
import lang::typhonql::Session;
import lang::typhonql::TDBC;
import lang::typhonql::Order;
import lang::typhonql::References;

import lang::typhonql::relational::SQL;
import lang::typhonql::relational::Util;
import lang::typhonql::relational::SQL2Text;

import lang::typhonql::mongodb::DBCollection;

import IO;
import ValueIO;
import List;
import String;

bool hasId({KeyVal ","}* kvs) = hasId([ kv | KeyVal kv <- kvs ]);

bool hasId(list[KeyVal] kvs) = any((KeyVal)`@id: <Expr _>` <- kvs);

str evalId({KeyVal ","}* kvs) = "<e>"[1..]
  when (KeyVal)`@id: <UUID e>` <- kvs;


str uuid2str(UUID ref) = "<ref>"[1..];

alias InsertContext = tuple[
  str entity,
  {KeyVal ","}* kvs,
  Bindings myParams,
  SQLExpr sqlMe,
  DBObject mongoMe,
  void (list[Step]) addSteps,
  void (SQLStat(SQLStat)) updateSQLInsert,
  Schema schema
];

Script insert2script((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, Schema s) {
  str entity = "<e>";
  Place p = placeOf(entity, s);
  str myId = newParam();
  Bindings myParams = ( myId: generatedId(myId) | !hasId(kvs) );
  SQLExpr sqlMe = hasId(kvs) ? lit(text(evalId(kvs))) : SQLExpr::placeholder(name=myId);
  DBObject mongoMe = hasId(kvs) ? \value(evalId(kvs)) : DBObject::placeholder(name=myId);
  

  SQLStat theInsert = \insert(tableName("<e>"), [], []);
  
  void addSteps(list[Step] steps) {
    scr.steps += steps;
  }
  
  void updateSQLInsert(SQLStat(SQLStat) block) {
    int idx = hasId(kvs) ? 0 : 1;
    theInsert = block(theInsert);
    scr.steps[idx] = step(p.dbName, sql(executeStatement(p.dbName, pp(theInsert))), myParams);
  }

  addSteps([ newId(myId) | !hasId(kvs) ]);
  
  // initialize
  updateSQLInsert(SQLStat(SQLStat ins) { return ins; });

  InsertContext ctx = <
    entity,
    kvs,
    myParams,
    sqlMe,
    mongoMe,
    addSteps,
    updateSQLInsert,
    s
  >;
  
  compileAttrs(p, [ kv | Keyval <- kvs, isAttr(kv, s) ], ctx);
  
  for ((KeyVal)`<Id x>: <UUID ref>` <- kvs) {
    str fromRole = "<x>"; 
    for (r:<entity, _, fromRole, _, _, str to, _> <- s) {
      compileRefBinding(p, placeOf(to, s), from, fromRole, ref, r, ctx);
    }
  }

  for ((KeyVal)`<Id x>: [<{UUID ","}* refs>]` <- kvs) {
    str fromRole = "<x>"; 
    for (r:<entity, _, fromRole, _, _, str to, _> <- s) {
      compileRefBindingMany(p, placeOf(to, s), from, fromRole, refs, r, ctx);
    }
  }

}


void compileAttrs(<sql(), str dbName>, list[KeyVal] kvs, InsertContext ctx) {
  ctx.updateSqlInsert(SQLStat(SQStat ins) {
     ins.colNames = [ *columnName(kv, ctx.entity) | KeyVal kv  <- kvs ] + [ typhonId(ctx.entity) ];
     ins.values =  [ *evalKeyVal(kv) | KeyVal kv <- kvs ] + [ ctx.sqlMe ];
     return ins;
  });
} 

void compileAttrs(<mongo(), str dbName>, list[KeyVal] kvs, InsertContext ctx) {
  DBObject obj = object([ keyVal2prop(kv) | KeyVal kv <- kvs ] + [ <"_id", mongoMe> | !hasId(kvs) ]);
  ctx.addSteps([step(dbName, mongo(insertOne(dbName, "<e>", pp(obj))), ctx.myParams)]);
}
      

void compileRefBinding(
  p:<sql(), str dbName>, <sql(), dbName>, str from, str fromRole, 
  <from, _, fromRole, str toRole, Cardinality toCard, str to, true>,
  UUID ref, InsertContext ctx
) {
  // update ref's foreign key to point to sqlMe
  str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
  SQLStat theUpdate = update(tableName(to), [\set(fk, ctx.sqlMe)],
    [where([equ(column(tableName(to), typhonId(to)), lit(text("<ref>"[1..])))])]);
                
  ctx.addSteps([step(dbName, sql(executeStatement(dbName, pp(theUpdate))), ctx.myParams)]);

}
      
void compileRefBinding(
  p:<sql(), str dbName>, <sql(), other:!dbName>, str from, str fromRole,
  <from, _, fromRole, str toRole, Cardinality toCard, str to, true>,
  UUID ref, InsertContext ctx
) {

  // insert entry in junction table between from and to on the current place.
  ctx.addSteps(insertIntoJunction(p.name, from, fromRole, to, toRole, ctx.sqlMe, [lit(text("<ref>"[1..]))], ctx.myParams));
  ctx.addSteps(insertIntoJunction(other, to, toRole, from, fromRole, lit(text("<ref>"[1..])), [ctx.sqlMe], ctx.myParams));
}   

void compileRefBinding(
  p:<sql(), str dbName>, <mongo(), str other>, str from, str fromRole,
  <from, _, fromRole, str toRole, Cardinality toCard, str to, true>,
  UUID ref, InsertContext ctx
) {
  // insert entry in junction table between from and to on the current place.
  ctx.addSteps(insertIntoJunction(p.name, from, fromRole, to, toRole, ctx.sqlMe, [lit(text("<ref>"[1..]))], ctx.myParams));
  ctx.addSteps(insertObjectPointer(other, to, toRole, toCard, \value("<ref>"[1..]), ctx.mongoMe, ctx.myParams));
}

void compileRefBinding(
  p:<sql(), str dbName>, <sql(), dbName>, str from, str fromRole,
  <str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true>,
  UUID ref, InsertContext ctx
) {
  // set foreign key of sqlMe to point to uuid
  str fk = fkName(parent, from, fromRole == "" ? parentRole : fromRole);
  ctx.updateSQLInsert(SQLStat(SQLStat theInsert) {
    theInsert.colNames += [ fk ];
    theInsert.values += [ lit(text(uuid2str(ref))) ];
    return theInsert;
  });
 }   

void compileRefBinding(
  p:<sql(), str dbName>, <sql(), other:!dbName>, str from, str fromRole,
  <str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true>,
  UUID ref, InsertContext ctx
) {      
  ctx.addSteps(insertIntoJunction(p.name, from, fromRole, parent, parentRole, lit(text(uuid2str(ref))), [ctx.sqlMe], ctx.myParams));
  ctx.addSteps(insertIntoJunction(other, parent, parentRole, from, fromRole, lit(text(uuid2str(ref))), [ctx.sqlMe], ctx.myParams));
}


void compileRefBinding(
  p:<sql(), str dbName>, <mongo(), str other>, str from, str fromRole,
  <str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true>,
  UUID ref, InsertContext ctx
) {
  ctx.addSteps(insertIntoJunction(p.name, from, fromRole, parent, parentRole, lit(text(uuid2str(ref))), [ctx.sqlMe], ctx.myParams));
  ctx.addSteps(updateObjectPointer(other, parent, parentRole, parentCard, \value(uuid2str(ref)), ctx.mongoMe, ctx.myParams));
}

void compileRefBinding(
  p:<sql(), str dbName>, <sql(), dbName>, str from, str fromRole,
  r:<from, _, fromRole, str toRole, Cardinality toCard, str to, false>,
  UUID ref, InsertContext ctx
) {
  if (r notin trueCrossRefs(ctx.schema)) {
    fail;
  }
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [lit(text(uuid2str(ref)))], ctx.myParams));
}

void compileRefBinding(
  p:<sql(), str dbName>, <sql(), other:!dbName>, str from, str fromRole,
  r:<from, _, fromRole, str toRole, Cardinality toCard, str to, false>,
  UUID ref, InsertContext ctx
) {
  if (r notin trueCrossRefs(ctx.schema)) {
    fail;
  }
  ctx.addSteps(insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, [lit(text(uuid2str(ref)))], ctx.myParams));
  ctx.addSteps(insertIntoJunction(other, to, toRole, from, fromRole, lit(text(uuid2str(ref))), [ctx.sqlMe], ctx.myParams));
}

void compileRefBinding(
  p:<sql(), str dbName>, <mongo(), str other>, str from, str fromRole,
  r:<from, _, fromRole, str toRole, Cardinality toCard, str to, false>,
  UUID ref, InsertContext ctx
) {
  if (r notin trueCrossRefs(ctx.schema)) {
    fail;
  }
  ctx.addSteps(updateObjectPointer(other, to, toRole, toCard, \value(uuid2str(ref)), ctx.mongoMe, ctx.myParams));
}


void compileRefBindingMany(
 p:<sql(), str dbName>, <sql(), dbName>, str from, str fromRole,
 <from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
 {UUID ","}* refs, InsertContext ctx
) {
  str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
  SQLStat theUpdate = update(tableName(to), [\set(fk, ctx.sqlMe)],
     [where([\in(column(tableName(to), typhonId(to)), [ evalExpr((Expr)`<UUID ref>`) | UUID ref <- refs])])]);
                
  ctx.addSteps([step(dbName, sql(executeStatement(dbName, pp(theUpdate))), ctx.myParams)]);
}

void compileRefBindingMany(
 p:<sql(), str dbName>, <sql(), other:!dbName>, str from, str fromRole,
 <from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
 {UUID ","}* refs, InsertContext ctx
) {
  // insert entry in junction table between from and to on the current place.
  ctx.addSteps(insertIntoJunction(p.name, from, fromRole, to, toRole, ctx.sqlMe, [lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams));
  ctx.addSteps([ *insertIntoJunction(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), [ctx.sqlMe], ctx.myParams) | UUID ref <- refs ]);
}

void compileRefBindingMany(
 p:<sql(), str dbName>, <mongo(), str other>, str from, str fromRole,
 <from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true>,
 {UUID ","}* refs, InsertContext ctx
) {
  ctx.addSteps(insertIntoJunction(p.name, from, fromRole, to, toRole, ctx.sqlMe, [lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams));
  ctx.addSteps([ *insertObjectPointer(other, to, toRole, toCard, \value("<ref>"[1..]), ctx.mongoMe, ctx.myParams) 
                | UUID ref <- refs ]);
} 

void compileRefBindingMany(
 p:<sql(), str dbName>, _, str from, str fromRole,
 <str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true>,
 {UUID ","}* refs, InsertContext ctx
) {
  throw "Cannot have multiple parents <refs> for inserted object <ctx.sqlMe>";
}


void compileRefBindingMany(
 p:<sql(), str dbName>, <sql(), dbName>, str from, str fromRole,
 <from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
 {UUID ","}* refs, InsertContext ctx
) {
  // save the cross ref
  ctx.addSteps([ *insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
    [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams) ]);
}

void compileRefBindingMany(
 p:<sql(), str dbName>, <sql(), other:!dbName>, str from, str fromRole,
 <from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
 {UUID ","}* refs, InsertContext ctx
) {
  ctx.addSteps([ *insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
    [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams) ]);
    
  ctx.addSteps([*insertIntoJunction(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), ctx.sqlMe, ctx.myParams)
                  | UUID ref <- refs ]);
}

void compileRefBindingMany(
 p:<sql(), str dbName>, <mongo(), str other>, str from, str fromRole,
 <from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, false>,
 {UUID ","}* refs, InsertContext ctx
) {
  ctx.addSteps([ *insertIntoJunction(dbName, from, fromRole, to, toRole, ctx.sqlMe, 
    [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], ctx.myParams) ]);
  ctx.addSteps([*insertObjectPointer(other, to, toRole, toCard, \value("<ref>"[1..]), ctx.mongoMe, ctx.myParams)
                 | UUID ref <- refs]);
}


/*
   

    case <mongodb(), str dbName>: {
      DBObject obj = object([ keyVal2prop(kv) | KeyVal kv <- kvs ]
                          + [ <"_id", mongoMe> | !hasId(kvs) ]);
                          
      list[Step] steps = [step(dbName, mongo(insertOne(dbName, "<e>", pp(obj))), myParams)];

      // refs/containment are direct, but we need to update the other direction.
      for ((KeyVal)`<Id x>: <UUID ref>` <- kvs) {
        str from = "<e>";
        str fromRole = "<x>";
        str uuid = "<ref>"[1..];
        

        if (<from, _, fromRole, str toRole, Cardinality toCard, str to, _> <- s.rels) {
          switch (placeOf(to, s)) {
          
            case <mongodb(), dbName> : {  
              // update uuid's toRole to me
              steps += insertObjectPointer(dbName, to, toRole, toCard, \value(uuid), mongoMe, myParams);
            }
            
            case <mongo(), str other> : {
              // update uuid's toRole to me, but on other db
              steps += insertObjectPointer(other, to, toRole, toCard, \value(uuid), mongoMe, myParams);
            }
            
            case <sql(), str other>: {
              steps += insertIntoJunction(other, to, toRole, from, fromRole, lit(text(uuid)), [sqlMe], myParams);
            }
            
          }
        }
      
      }
      
      for ((KeyVal)`<Id x>: [<{UUID ","}* refs>]` <- kvs) {
        str from = "<e>";
        str fromRole = "<x>";


        if (<from, _, fromRole, str toRole, Cardinality toCard, str to, _> <- s.rels) {
          switch (placeOf(to, s)) {
          
            case <mongodb(), dbName> : {  
              steps += [ *insertObjectPointer(dbName, to, toRole, toCard, \value("<ref>"[1..]) , mongoMe, myParams)
                | UUID ref <- refs ];
            }
            
            case <mongo(), str other> : {
              steps += [ *insertObjectPointer(dbName, to, toRole, toCard, \value("<ref>"[1..]) , mongoMe, myParams)
                | UUID ref <- refs ];
            }
            
            case <sql(), str other>: {
              steps += [ *insertIntoJunction(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), sqlMe, myParams)
                | UUID ref <- refs ];
            }
            
          }
        }
      }

      return script([ newId(myId) | !hasId(kvs) ] + steps);
    }
  }
}

*/

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

DBObject obj2DbObj((Expr)`<DateTime d>`) 
  = object([<"$date", \value(readTextValueString(#datetime, "<d>"))>]);

DBObject obj2DbObj((Expr)`#point(<Real x> <Real y>)`) 
  = object([<"type", \value("Point")>, 
      <"coordinates", array([\value(toReal("<x>")), \value(toReal("<y>"))])>]);

DBObject obj2DbObj((Expr)`#polygon(<{Segment ","}* segs>)`) 
  = object([<"$polygon", array([ seg2array(s) | Segment s <- segs ])>]);

DBObject seg2array((Segment)`(<{XY ","}* xys>)`)
  = array([ array([\value(toReal(x)), \value(toReal(y))]) | (XY)`<Real x> <Real y>` <- xys ]);


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

list[SQLExpr] evalKeyVal((KeyVal)`<Id _>: <Expr e>`) = [lit(evalExpr(e))]
	when (Expr) `<Custom c>` !:= e;

list[Value] evalKeyVal((KeyVal)`@id: <Expr e>`) = [evalExpr(e)];

Value evalExpr((Expr)`<VId v>`) { throw "Variable still in expression"; }
 
// todo: unescaping (e.g. \" to ")!
Value evalExpr((Expr)`<Str s>`) = text("<s>"[1..-1]);

Value evalExpr((Expr)`<Int n>`) = integer(toInt("<n>"));

Value evalExpr((Expr)`<Bool b>`) = boolean("<b>" == "true");

Value evalExpr((Expr)`<Real r>`) = decimal(toReal("<r>"));

Value evalExpr((Expr)`#point(<Real x> <Real y>)`) = point(toReal("<x>", toReal("<y>")));

Value evalExpr((Expr)`#polygon(<{Segment ","}* segs>)`)
  = polygon([ seg2lrel(s) | Segment s <- segs ]);
  
lrel[real, real] seg2lrel((Segment)`(<{XY ","}* xys>)`)
  = [ <toReal("<x>"), toReal("<y>")> | (XY)`<Real x> <Real y>` <- xys ]; 

Value evalExpr((Expr)`<DateAndTime d>`) = dateTime(readTextValueString(#datetime, "<d>"));

Value evalExpr((Expr)`<JustDate d>`) = date(readTextValueString(#datetime, "<d>"));

// should only happen for @id field (because refs should be done via keys etc.)
Value evalExpr((Expr)`<UUID u>`) = text("<u>"[1..]);

Value evalExpr((Expr)`<PlaceHolder p>`) = placeholder(name="<p>"[2..]);

default Value evalExpr(Expr _) = null();

bool isAttr((KeyVal)`<Id x>: <Expr _>`, str e, Schema s) = <e, "<x>", _> <- s.attrs;

bool isAttr((KeyVal)`<Id x> +: <Expr _>`, str e, Schema s) = false;

bool isAttr((KeyVal)`<Id x> -: <Expr _>`, str e, Schema s) = false;

bool isAttr((KeyVal)`@id: <Expr _>`, str _, Schema _) = false;
  

