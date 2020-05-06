module lang::typhonql::cassandra::CQL2Text

import lang::typhonql::cassandra::CQL;

import List;
import String;



str pp(cTimestamp(int microSeconds)) = "TIMESTAMP <microSeconds>";

str pp(cTTL(int seconds)) = "TTL <seconds>";

str pp(cColumn(str name)) = name;

str pp(cIndexed(str name, CQLExpr index))
  = "<name>[<pp(index)>]";
  
str pp(cSubfield(str name, str field))
  = "<name>.<field>";
  
str pp(cSimple(CQLSimpleSelection selection, CQLExpr term)) 
  = "<pp(selection)> = <pp(term)>";

str pp(cIncr(str target, str other, CQLExpr term)) 
  = "<target> = <other> + <pp(term)>";
  
str pp(cDecr(str target, str other, CQLExpr term)) 
  = "<target> = <other> - <pp(term)>";
  
str pp(cConcat(str target, CQLValue lst, str other)) 
  = "<target> = <pp(lst)> + <other>";
 
str pp(cStar()) = "*";

str pp(cSelector(CQLExpr e, as=str as))
  = as == "" ? pp(e) : "<pp(e)> AS <as>";

str pp(cOrder(str name, bool asc)) = "<name> <asc ? "ASC" : "DESC">";

/*
 * Expressions
 */

str pp(cColumn(str name)) = name;
str pp(cTerm(CQLValue val)) = pp(val);
str pp(cCast(CQLExpr arg, CQLType \type)) = "CAST(<pp(arg)> AS <pp(\type)>)";
str pp(cCall(str name, list[CQLExpr] args)) = "<name>(<intercalate(", ", [ pp(a) | CQLExpr a <- args ])>)";
str pp(cCount()) = "COUNT(*)";
str pp(cEq(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> = <pp(rhs)>";
str pp(cNeq(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> != <pp(rhs)>";
str pp(cLeq(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> \<= <pp(rhs)>";
str pp(cGeq(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> \>= <pp(rhs)>";
str pp(cLt(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> \< <pp(rhs)>";
str pp(cGt(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> \> <pp(rhs)>";
str pp(cIn(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> IN <pp(rhs)>";
str pp(cContains(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> CONTAINS <pp(rhs)>";
str pp(cContainsKey(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> CONTAINS KEY <pp(rhs)>";

/*
 * Types
 */
 
str pp(cASCII()) = "ascii";
str pp(cBigInt()) = "bigint";
str pp(cBlob()) = "blob";
str pp(cBoolean()) = "boolean";
str pp(cCounter()) = "counter";
str pp(cDate()) = "date";
str pp(cDecimal()) = "decimal";
str pp(cDouble()) = "double";
str pp(cDuration()) = "duration";
str pp(cFloat()) = "float";
str pp(cInet()) = "inet";
str pp(cInt()) = "int";
str pp(cSmallInt()) = "smallint";
str pp(cText()) = "text";
str pp(cTime()) = "time";
str pp(cTimestamp()) = "timestamp";
str pp(cTimeUUID()) = "timeuuid";
str pp(cTinyInt()) = "tinyint";
str pp(cUUID()) = "uuid";
str pp(cVarchar()) = "varchar";
str pp(cVarint()) = "varint";
str pp(cMap(CQLType keyType, CQLType valueType)) = "map\<<pp(keyType)>,<pp(valueType)>\>";
str pp(cSet(CQLType elementType)) = "set\<<pp(elementType)>\>";
str pp(cList(CQLType listType)) = "list\<<pp(listType)>\>";

str pp(cTuple(list[CQLType] \types)) 
  = "tuple\<<intercalate(", ", [ pp(t) | CQLType t <- \types ])>\>";

str pp(cUserDefined(str name, keySpace=str keySpace)) 
  =  keySpace == "" ? name : "<keySpace>.<name>";
  
str pp(cFrozen(CQLType arg)) = "frozen\<<pp(arg)>\>";

/*
 * Values
 */
 
// todo: escaping etc.
str pp(cString(str s)) = "\'<s>\'";

str pp(cInteger(int i)) = "<i>";

str pp(cBoolean(bool b)) = "<b>";

str pp(cFloat(real r)) = "<r>";

str pp(cUUID(str u)) = u;

str pp(cMap(map[CQLValue, CQLValue] m))
  = "{<intercalate(", ", [ "<pp(k)>: <pp(m[k])>" | CQLValue k <- m ])>}"; 

str pp(cSet(set[CQLValue] s))
  = "{<intercalate(", ", [ pp(v) | CQLValue v <- s ])>}";

str pp(cList(list[CQLValue] l))
  = "[<intercalate(", ", [ pp(v) | CQLValue v <- l ])>]";

str pp(cTuple(list[CQLValue] l))
  = "(<intercalate(", ", [ pp(v) | CQLValue v <- l ])>)";
  
  
str pp(cUserDefined(map[str,CQLValue] m))
  = "{<intercalate(", ", [ "<k>: <pp(m[k])>" | CQLValue k <- m ])>}";
  
