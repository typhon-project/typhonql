module lang::typhonql::relational::Insert2SQL



import lang::typhonql::TDBC;
import lang::typhonql::Script;
import lang::typhonql::Session;

import lang::typhonql::relational::SQL;
import lang::typhonql::relational::SQL2Text;
import lang::typhonql::relational::Util;

import lang::typhonml::Util;
import lang::typhonml::TyphonML;


import IO;
import String;

// no nested objects are allowed, only primitives and refs
// entity refs may only be the "canonical" ones.

// todo: move to schema/Util
Place placeOf(str entity, Schema s) = p
  when 
    <Place p, entity> <- s.placement;

bool bothAt(str from, str to, Place p, Schema s) = placeOf(from, s) == p && placeOf(to, s) == p;


alias ParentFK = tuple[str col, str val];

// TODO typechecker: if e has owner, disallow this form.
list[Step] insert2sql((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, Schema s, Place p, SQLExpr myId, Bindings myParams, ParentFK parent = <"", "">) {
  
  list[str] aCols({KeyVal ","}* kvs, str entity) 
    = [ *columnName(kv, entity) | KeyVal kv  <- kvs, isAttr(kv, entity, s)]
    + [ typhonId(entity) ]
    + [ parent.col | parent.col != "" ];
  
  list[SQLExpr] aVals({KeyVal ","}* kvs, str entity) 
    = [ *evalKeyVal(kv) | KeyVal kv <- kvs, isAttr(kv, entity, s) ]
    + [ myId ]
    + [ lit(text(parent.val[1..])) | parent.val != "" ];

  list[SQLStat] result = [ \insert(tableName("<e>"), aCols(kvs, "<e>"), aVals(kvs, "<e>")) ]; 
  
  
  // for all non-attr reference bindings
  result += outer: for ((KeyVal)`<Id x>: <UUID ref>` <- kvs) {
      str from = "<e>";
      str fromRole = "<x>";
      str uuid = "<ref>"[1..];
      
      // the below holds only for when both from and to are on the same place
      if (<from, _, fromRole, str toRole, _, to, true> <- s.rels, bothAt(from, to, p, s)) {
        // found the canonical containment rel
        // but then reverse!!    
        str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
        append outer: update(tableName(to), [\set(fk, myId)],
            [where([equ(column(tableName(to), typhonId(to)), lit(text(uuid)))])]);
      }
      else if (<to, _, str toRole, fromRole, _, from, true> <- s.rels, bothAt(from, to, p, s)) {
        str fk = fkName(from, to, toRole == "" ? fromRole : toRole);
        append outer: update(tableName(from), [\set(fk, lit(text(uuid)))],
          [where([equ(column(tableName(from), typhonId(from)), myId)])]);
      }
      else if (<from, _, fromRole, str toRole, _, to, false> <- s.rels, bothAt(from, to, p, s))  { // a cross ref
        append outer: \insert(junctionTableName(from, fromRole, to, toRole)
                        , [junctionFkName(from, fromRole), junctionFkName(to, toRole)]
                        , [myId, lit(text(uuid))]);
      }
      else if (<from, _, fromRole, str toRole, _, to, _> <- s.rels, !bothAt(from, to, p, s))  { 
         append outer: \insert(junctionTableName(from, fromRole, to, toRole)
                        , [junctionFkName(from, fromRole), junctionFkName(to, toRole)]
                        , [myId, lit(text(uuid))]);
      }
      else {
        throw "Reference <from>.<fromRole> not found in schema.";
      }
  }
      
  return  [ step(p.name, sql(executeStatement(p.name, pp(stat))), myParams) | SQLStat stat <- result ];
}

// this function assumes the parent is local; if it is outside it should be dealt with higher-up
// (e.g. in the compile functions of Request2Script)
list[Step] insert2sql((Request)`insert <EId e> { <{KeyVal ","}* kvs> } into <UUID owner>.<Id field>`, Schema s, Place p, SQLExpr myId, Bindings myParams) {

  if (<str parent, _, str fromRole, str toRole, _, str to, _> <- s.rels, fromRole == "<field>", to == "<e>") {
    assert bothAt(parent, "<e>", p, s);
    str fk = fkName(parent, to, toRole == "" ? fromRole : toRole);
    return insert2sql((Request)`insert <EId e> { <{KeyVal ","}* kvs> }`, s, p, myId, myParams, parent = <fk, "<owner>">);
  }
  
  throw "no parent entity at db <p> found owning <e> through field <field>";
}

// this should be somewhere shared
bool isAttr((KeyVal)`<Id x>: <Expr _>`, str e, Schema s) = <e, "<x>", _> <- s.attrs;

bool isAttr((KeyVal)`<Id x> +: <Expr _>`, str e, Schema s) = false;

bool isAttr((KeyVal)`<Id x> -: <Expr _>`, str e, Schema s) = false;

bool isAttr((KeyVal)`@id: <Expr _>`, str _, Schema _) = false;
  

void smokeInsert2SQL() {
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
    <<sql(), "Inventory">, "Review">,
    <<sql(), "Inventory">, "Comment">
  } 
  );
  
  void toSql(Request r) {
    println("Compiling `<r>`");
    <stats, bindings> = insert2sql(r, s, <sql(), "Inventory">);
    for (SQLStat stat <- stats) {
      println(pp(stat));
    }
  }
  
  toSql((Request)`insert Person {name: "Pablo", age: 23}`);
  toSql((Request)`insert Person {name: "Pablo", age: 23, reviews: #abc, reviews: #cdef}`);
  
  toSql((Request)`insert Review {text: "Bad"} into #pablo.reviews`);
    
}




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
