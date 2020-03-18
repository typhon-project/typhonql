module lang::typhonql::relational::Update2SQL


import lang::typhonql::TDBC;
import lang::typhonql::util::Objects;

import lang::typhonql::relational::SQL;
import lang::typhonql::relational::Select2SQL;
import lang::typhonql::relational::Util;

import lang::typhonml::Util; // Schema
import lang::typhonml::TyphonML;


import IO;
import String;
import ValueIO;

list[SQLStat] update2sql((Request)`update <EId e> <VId x> where <{Expr ","}+ es> set {<{KeyVal ","}* kvs>}`, Schema schema) {
  q = select2sql((Query)`from <EId e> <VId x> select "" where <{Expr ","}+ es>`, schema);
  
  // TODO: assigning a ref to an owned thing needs updating the kid table.
  // and similar for cross references.
  
  return [update(tableName("<e>"),
      [ \set(columnName(kv, "<e>"), lit(evalExpr(kv.\value))) | KeyVal kv <- kvs ],
      q.clauses)];
}

list[str] columnName((KeyVal)`<Id x>: <EId customType> (<{KeyVal ","}* keyVals>)`, str entity) = [columnName("<x>", entity, "<customType>", "<y>") | (KeyVal)`<Id y>: <Expr e>` <- keyVals];

list[str] columnName((KeyVal)`<Id x>: <Expr e>`, str entity) = [columnName("<x>", entity)]
	when (Expr) `<Custom c>` !:= e;

list[str] columnName((KeyVal)`@id: <Expr _>`, str entity) = [typhonId(entity)]; 

list[Value] evalKeyVal((KeyVal) `<Id x>: <EId customType> (<{KeyVal ","}* keyVals>)`) = [evalExpr(e) | (KeyVal)`<Id x>: <Expr e>` <- keyVals];

list[Value] evalKeyVal((KeyVal)`<Id _>: <Expr e>`) = [evalExpr(e)]
	when (Expr) `<Custom c>` !:= e;

list[Value] evalKeyVal((KeyVal)`@id: <Expr e>`) = [evalExpr(e)];

bool isAttr((KeyVal)`<Id x>: <Expr _>`, str e, Schema s) = <e, "<x>", _> <- s.attrs;

bool isAttr((KeyVal)`<Id x> +: <Expr _>`, str e, Schema s) = false;

bool isAttr((KeyVal)`<Id x> -: <Expr _>`, str e, Schema s) = false;

bool isAttr((KeyVal)`@id: <Expr _>`, str _, Schema _) = true;
  

 