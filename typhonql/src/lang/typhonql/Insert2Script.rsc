module lang::typhonql::Insert2Script

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
import List;
import String;

bool hasId({KeyVal ","}* kvs) = any((KeyVal)`@id: <Expr _>` <- kvs);

str evalId({KeyVal ","}* kvs) = "<e>"[1..]
  when (KeyVal)`@id: <UUID e>` <- kvs;



Script insert2script((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, Schema s) {
  
  //s.rels = symmetricReduction(s.rels);
  
  Place p = placeOf("<e>", s);
  str myId = newParam();
  Bindings myParams = ( myId: generatedId(myId) | !hasId(kvs) );
  SQLExpr sqlMe = hasId(kvs) ? lit(text(evalId(kvs))) : SQLExpr::placeholder(name=myId);
  DBObject mongoMe = hasId(kvs) ? \value(evalId(kvs)) : DBObject::placeholder(name=myId);
  
  list[Step] steps = [];    
      
  switch (p) {
    case <sql(), str dbName>: {
      
      list[str] aCols({KeyVal ","}* kvs, str entity) 
	    = [ *columnName(kv, entity) | KeyVal kv  <- kvs, isAttr(kv, entity, s)]
	    + [ typhonId(entity) ];
  
	  list[SQLExpr] aVals({KeyVal ","}* kvs, str entity) 
	    = [ *evalKeyVal(kv) | KeyVal kv <- kvs, isAttr(kv, entity, s) ]
	    + [ sqlMe ];
      
      SQLStat theInsert = \insert(tableName("<e>"), aCols(kvs, "<e>"), aVals(kvs, "<e>")) ; 
      
      for ((KeyVal)`<Id x>: <UUID ref>` <- kvs) {
        str from = "<e>";
        str fromRole = "<x>";
        str uuid = "<ref>"[1..];
        if (<from, _, fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels) {
            // this keyval is updating ref to have me as a foreign key
            
          switch (placeOf(to, s)) {
          
            case <sql(), dbName> : {  
              // update ref's foreign key to point to sqlMe
              str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
              SQLStat theUpdate = update(tableName(to), [\set(fk, sqlMe)],
                [where([equ(column(tableName(to), typhonId(to)), lit(text(uuid)))])]);
                
              steps += [step(dbName, sql(executeStatement(dbName, pp(theUpdate))), myParams)];
            }
            
            case <sql(), str other> : {
               // insert entry in junction table between from and to on the current place.
              steps += insertIntoJunction(p.name, from, fromRole, to, toRole, sqlMe, [lit(text(uuid))], myParams);
              steps += insertIntoJunction(other, to, toRole, from, fromRole, lit(text(uuid)), [sqlMe], myParams);
            }
            
            case <mongodb(), str other>: {
              // insert entry in junction table between from and to on the current place.
              steps += insertIntoJunction(p.name, from, fromRole, to, toRole, sqlMe, [lit(text(uuid))], myParams);
              steps += insertObjectPointer(other, to, toRole, toCard, \value(uuid), mongoMe, myParams);
            }
            
          }
        }
        else if (<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true> <- s.rels) {
           // this is the case that the current KeyVal pair is actually
           // setting the currently inserted object as being owned by ref
           
           switch (placeOf(parent, s)) {
             case <sql(), dbName>: {
               // set foreign key of sqlMe to point to uuid
                str fk = fkName(parent, from, fromRole == "" ? parentRole : fromRole);
                theInsert.colNames += [ fk ];
                theInsert.values += [ lit(text(uuid)) ];
             }
             case <sql(), str other>: {
                steps += insertIntoJunction(p.name, from, fromRole, parent, parentRole, lit(text(uuid)), [sqlMe], myParams);
                steps += insertIntoJunction(other, parent, parentRole, from, fromRole, lit(text(uuid)), [sqlMe], myParams);
             }
             case <mongodb(), str other>: {
               steps += insertIntoJunction(p.name, from, fromRole, parent, parentRole, lit(text(uuid)), [sqlMe], myParams);
               steps += updateObjectPointer(other, parent, parentRole, parentCard, \value(uuid), mongoMe, myParams);
             }
           }
        } 
        
        // xrefs are symmetric, so both directions are done in one go. 
        else if (<from, _, fromRole, str toRole, Cardinality toCard, str to, false> <- trueCrossRefs(s.rels)) {
           // save the cross ref
           steps += insertIntoJunction(dbName, from, fromRole, to, toRole, sqlMe, [lit(text(uuid))], myParams);
           
           // and the opposite sides
           switch (placeOf(to, s)) {
             case <sql(), dbName>: {
               ; // nothing to be done, locally, the same junction table is used
               // for both directions.
             }
             case <sql(), str other>: {
               steps += insertIntoJunction(other, to, toRole, from, fromRole, lit(text(uuid)), [sqlMe], myParams);
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
      
      for ((KeyVal)`<Id x>: [<{UUID ","}+ refs>]` <- kvs) {
        str from = "<e>";
        str fromRole = "<x>";
        if (<from, Cardinality fromCard, fromRole, str toRole, Cardinality toCard, str to, true> <- s.rels) {
            // this keyval is updating ref to have me as a foreign key
            
          switch (placeOf(to, s)) {
          
            case <sql(), dbName> : {  
              // update each ref's foreign key to point to sqlMe
              str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
              SQLStat theUpdate = update(tableName(to), [\set(fk, sqlMe)],
                [where([\in(column(tableName(to), typhonId(to)), [ evalExpr((Expr)`<UUID ref>`) | UUID ref <- refs])])]);
                
              steps += [step(dbName, sql(executeStatement(dbName, pp(theUpdate))), myParams)];
            }
            
            case <sql(), str other> : {
               // insert entry in junction table between from and to on the current place.
              steps += insertIntoJunction(p.name, from, fromRole, to, toRole, sqlMe, [lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], myParams);
              steps += [ *insertIntoJunction(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), [sqlMe], myParams) | UUID ref <- refs ];
            }
            
            case <mongodb(), str other>: {
              steps += insertIntoJunction(p.name, from, fromRole, to, toRole, sqlMe, [lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], myParams);
              steps += [ *insertObjectPointer(other, to, toRole, toCard, \value("<ref>"[1..]), mongoMe, myParams) 
                | UUID ref <- refs ] ;
            }
            
          }
        }
        else if (<str parent, Cardinality parentCard, str parentRole, fromRole, _, from, true> <- s.rels) {
           // this is the case that the current KeyVal pair is actually
           // setting the currently inserted object as being owned by each ref which is illegal
           throw "Cannot have multiple parents <refs> for inserted object";
        } 
        
        // xrefs are symmetric, so both directions are done in one go. 
        else if (<from, _, fromRole, str toRole, Cardinality toCard, str to, false> <- trueCrossRefs(s.rels)) {
           // save the cross ref
           steps += [ *insertIntoJunction(dbName, from, fromRole, to, toRole, sqlMe, [ lit(evalExpr((Expr)`<UUID ref>`)) | UUID ref <- refs ], myParams) ];
           
           // and the opposite sides
           switch (placeOf(to, s)) {
             case <sql(), dbName>: {
               ; // nothing to be done, locally, the same junction table is used
               // for both directions.
             }
             case <sql(), str other>: {
               steps += [*insertIntoJunction(other, to, toRole, from, fromRole, lit(evalExpr((Expr)`<UUID ref>`)), sqlMe, myParams)
                  | UUID ref <- refs ];
             }
             case <mongodb(), str other>: {
               steps += [*insertObjectPointer(other, to, toRole, toCard, \value("<ref>"[1..]), mongoMe, myParams)
                 | UUID ref <- refs];
             }
           }
        
        }
        else {
          throw "Cannot happen";
        } 
        
         
      }
      
      
      // do the actual insert first.
      return script([ newId(myId) | !hasId(kvs) ] 
        + [step(dbName, sql(executeStatement(dbName, pp(theInsert))), myParams)] + steps);
    }

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
      
      for ((KeyVal)`<Id x>: [<{UUID ","}+ refs>]` <- kvs) {
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


DBObject obj2dbObj((Expr)`<EId e> {<{KeyVal ","}* kvs>}`)
  = object([ keyVal2prop(kv) | KeyVal kv <- kvs ]);
   
DBObject obj2dbObj((Expr)`[<{Obj ","}* objs>]`)
  = array([ obj2dbObj((Expr)`<Obj obj>`) | Obj obj <- objs ]);

DBObject obj2dbObj((Expr)`[<{UUID ","}+ refs>]`)
  = array([ obj2dbObj((Expr)`<UUID ref>`) | UUID ref <- refs ]);

DBObject obj2dbObj((Expr)`<Bool b>`) = \value("<b>" == "true");

DBObject obj2dbObj((Expr)`<Int n>`) = \value(toInt("<n>"));

DBObject obj2dbObj((Expr)`<DateTime d>`) 
  = \value(toInt("<n>"));
  
DBObject obj2dbObj((Expr)`<PlaceHolder p>`) = placeholder(name="<p>"[2..]);

DBObject obj2dbObj((Expr)`<UUID id>`) = \value("<id>"[1..]);

DBObject obj2DbObj((Expr)`<DateTime d>`) 
  = object([<"$date", \value(readTextValueString(#datetime, "<d>"))>]);


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

Value evalExpr((Expr)`<DateTime d>`) = dateTime(readTextValueString(#datetime, "<d>"));

// should only happen for @id field (because refs should be done via keys etc.)
Value evalExpr((Expr)`<UUID u>`) = text("<u>"[1..]);

Value evalExpr((Expr)`<PlaceHolder p>`) = placeholder(name="<p>"[2..]);

default Value evalExpr(Expr _) = null();

bool isAttr((KeyVal)`<Id x>: <Expr _>`, str e, Schema s) = <e, "<x>", _> <- s.attrs;

bool isAttr((KeyVal)`<Id x> +: <Expr _>`, str e, Schema s) = false;

bool isAttr((KeyVal)`<Id x> -: <Expr _>`, str e, Schema s) = false;

bool isAttr((KeyVal)`@id: <Expr _>`, str _, Schema _) = false;
  

