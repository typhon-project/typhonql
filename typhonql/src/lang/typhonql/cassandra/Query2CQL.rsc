module lang::typhonql::cassandra::Query2CQL

import lang::typhonql::Expr;
import lang::typhonql::Query;

import lang::typhonql::cassandra::CQL;


import String;
import ValueIO;
import DateTime;




CQLExpr expr2cql((Expr)`?`) = cBindMarker();

CQLExpr expr2cql((Expr)`<Int i>`) = cTerm(cInteger(integer(toInt("<i>"))));

CQLExpr expr2cql((Expr)`<Real r>`) = cTerm(cFloat(toReal("<r>")));

CQLExpr expr2cql((Expr)`<Str s>`) = cTerm(cString("<s>"[1..-1]));

// a la cql timestamp
CQLExpr expr2cql((Expr)`<DateAndTime d>`) 
  = cTerm(cString(printDate(readTextValueString(#datetime, "<d>"), "yyyy-MM-dd\'T\'HH:mm:ss.SSSZZ")));

CQLExpr expr2cql((Expr)`<JustDate d>`)  
  = cTerm(cString(printDate(readTextValueString(#datetime, "<d>"), "yyyy-MM-dd")));

CQLExpr expr2cql((Expr)`<UUID u>`) = cTerm(cUUID("<u>"[1..]));

CQLExpr expr2cql((Expr)`true`) = cTerm(cBoolean(true));

CQLExpr expr2cql((Expr)`false`) = cTerm(cBoolean(false));

CQLExpr expr2cql((Expr)`(<Expr e>)`) = expr2cql(e);

CQLExpr expr2cql((Expr)`null`) = cTerm(cNull());

CQLExpr expr2cql((Expr)`+<Expr e>`) = expr2cql(e);

CQLExpr expr2cql((Expr)`-<Expr e>`) = cUminus(expr2cql(e));

//CQLExpr expr2cql((Expr)`!<Expr e>`) = not(expr2cql(e));

CQLExpr expr2cql((Expr)`<Expr lhs> * <Expr rhs>`) 
  = cTimes(expr2cql(lhs), expr2cql(rhs));

CQLExpr expr2cql((Expr)`<Expr lhs> / <Expr rhs>`) 
  = cDiv(expr2cql(lhs), expr2cql(rhs));

CQLExpr expr2cql((Expr)`<Expr lhs> + <Expr rhs>`) 
  = cAdd(expr2cql(lhs), expr2cql(rhs));

CQLExpr expr2cql((Expr)`<Expr lhs> - <Expr rhs>`) 
  = cMinus(expr2cql(lhs), expr2cql(rhs));

CQLExpr expr2cql((Expr)`<Expr lhs> == <Expr rhs>`) 
  = cEq(expr2cql(lhs), expr2cql(rhs));

CQLExpr expr2cql((Expr)`<Expr lhs> != <Expr rhs>`) 
  = cNeq(expr2cql(lhs), expr2cql(rhs));

CQLExpr expr2cql((Expr)`<Expr lhs> \>= <Expr rhs>`) 
  = cGeq(expr2cql(lhs), expr2cql(rhs));

CQLExpr expr2cql((Expr)`<Expr lhs> \<= <Expr rhs>`) 
  = cLeq(expr2cql(lhs), expr2cql(rhs));

CQLExpr expr2cql((Expr)`<Expr lhs> \> <Expr rhs>`) 
  = cGt(expr2cql(lhs), expr2cql(rhs));

CQLExpr expr2cql((Expr)`<Expr lhs> \< <Expr rhs>`) 
  = cLt(expr2cql(lhs), expr2cql(rhs));

CQLExpr expr2cql((Expr)`<Expr lhs> in <Expr rhs>`)
  = cIn(expr2cql(lhs), expr2cql(rhs));

//CQLExpr expr2cql((Expr)`<Expr lhs> like <Expr rhs>`) 
//  = like(expr2cql(lhs), expr2cql(rhs));

//CQLExpr expr2cql((Expr)`<Expr lhs> && <Expr rhs>`) 
//  = and(expr2cql(lhs), expr2cql(rhs));

//CQLExpr expr2cql((Expr)`<Expr lhs> || <Expr rhs>`) 
//  = or(expr2cql(lhs), expr2cql(rhs));


default CQLExpr expr2cql(Expr e) { throw "Unsupported expression: <e>"; }
