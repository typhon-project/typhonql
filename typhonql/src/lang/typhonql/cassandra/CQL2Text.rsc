module lang::typhonql::cassandra::CQL2Text

import lang::typhonql::cassandra::CQL;

import List;
import String;
import IO;


str ppId(str name) = "\"<name>\"";

str pp(cCreateKeySpace(str name, ifNotExists=bool ine, with=map[str,CQLValue] with)) 
  = "CREATE KEYSPACE<ppINE(ine)> <ppId(name)><ppWith(with)>;";

str pp(cAlterKeySpace(str name, with=map[str,CQLValue] with))
  = "ALTER KEYSPACE <ppId(name)><ppWith(with)>;"; 

str pp(cDropKeySpace(str name, ifExists=bool ifExists)) 
  = "DROP KEYSPACE<ppIE(ifExists)> <ppId(name)>;";

 
str pp(cCreateTable(str name, list[CQLColumnDefinition] columns, CQLPrimaryKey primaryKey
      , ifNotExists=bool ifNotExists, with=map[str, value] with))
  = "CREATE TABLE<ppINE(ifNotExists)> <ppId(name)> (<ppColumns(columns, primaryKey)>)<ppWith(with)>;";
 
str pp(cAlterTable(str name, CQLAlterTableInstruction instruction))
  = "ALTER TABLE <ppId(name)><pp(instruction)>;";

str pp(cDropTable(str name, ifExists=bool ifExists))
  = "DROP TABLE<ppIE(ifExists)> <ppId(name)>;";

str pp(cTruncate(str name)) = "TRUNCATE TABLE <ppId(name)>;";

str pp(cCreateType(str name, lrel[str name, CQLType \type] fields, ifNotExists=bool ine))
  = "CREATE TYPE<ppINE(ine)> (<intercalate(", ", [ "<ppId(n)> <pp(t)>" | <str n, CQLTYpe t> <- fields ])>);";


str pp(cAlterType(str name, CQLAlterTypeModification modification))
  = "ALTER TYPE <ppId(name) <pp(modification)>;";
  
str pp(cDropType(str name, ifExists=bool ie))
  = "DROP TYPE<ppIE(ie)> <ppId(name)>;";


str pp(cSelect(list[CQLSelectClause] selectClauses, str tableName, list[CQLExpr] wheres, 
      groupBy=list[str] groupBy,
      orderBy=list[CQLOrderBy] orderBy, 
      perPartitionLimit=CQLExpr perPartitionLimit,
      limit=CQLExpr limit,
      allowFiltering=bool allowFiltering, 
      distinct=bool distinct, 
      json=bool json)) {
      
  str s = "SELECT";
 
  if (json) {
    s += " JSON ";
  }
 
  if (distinct) {
    s += " DISTINCT ";
  }    
 
  s += intercalate(", ", [ pp(sc) | CQLSelectClause sc <- selectClauses ]);

  s += " FROM <ppId(tableName)>";

  s += ppWhere(wheres);
  
  if (groupBy != []) {
    s += " GROUP BY <intercalate(", ", groupBy)>";
  }

  if (orderBy != []) {
    s += " ORDER BY <intercalate(", ", [ pp(ob) | CQLOrderBy ob <- orderBy ])>";
  }

  if (perPatitionLimit != cTerm(cInteger(-1))) {
    s += " PER PARTITION LIMIT <pp(perPartitionLimit)>";
  }

  if (limit != cTerm(cInteger(-1))) {
    s += " LIMIT <pp(limit)>";
  }

  if (allowFiltering) {
    s += " ALLOW FILTERING";
  }

  s += ";";

  return s;
}

str pp(cInsert(str name, list[str] cols, list[CQLValue] values, 
       ifNotExists=bool ine, 
       using=list[CQLUpdateParam] using)) 
  = "INSERT INTO <ppId(name)> (<intercalate(", ", cols)>) VALUES <pp(cTuple(values))><ppINE(ine)><ppUsing(using)>;";


str pp(cUpdate(str name, list[CQLAssignment] sets, list[CQLExpr] wheres,
      using=list[CQLUpdateParam] using,
      ifExists=bool ie,
      conditions=list[CQLExpr] conditions))
  = "UPDATE <ppId(name)><ppUsing(using)> <ppSets(sets)><ppWheres(wheres)><ppConds(io, conditions)>;";



/*
 * Auxiliar
 */
 
str ppConds(bool ifExists, list[CQLExpr] conds)
  = ifExists ? " IF EXISTS"
  : " IF <intercalate(" AND ", [ pp(c) | CQLExpr c <- conds ])>";

str ppSets(list[CQLAssignment] sets)
  = "SET <intercalate(", ", [ pp(s) | CQLAssignment s <- sets ])>";

str ppWhere(list[CQLExpr] wheres)
  = wheres != [] ? ""
    : " WHERE " + intercalate(" AND ", [ pp(e) | CQLExpr e <- wheres]);
  

str ppUsing(list[CQLUpdateParam] using)
  = using == [] ? ""
  : "USING <intercalate(" AND ", [ pp(up) | CQLUpdateParam up <- using ])>";
  
str pp(cTimeStamp(CQLExpr mus))
  = "TIMESTAMP <pp(mus)>";
  
str pp(cTTL(CQLExpr s))
  = "TTL <pp(s)>";
 
str pp(cAdd(str name, CQLType \type))
  = "ADD <ppId(name)> <pp(\type)>";
  
str pp(cRename(map[str old, str new] renamings))
  = "RENAME <intercalate(" ", [ "<ppId(x)> TO <ppId(renamings[x])>" | str x <- renamings ])>";

str pp(cAdd(list[CQLColumnDefinition] columns)) 
  = " ADD <intercalate(", ", [ "<ppId(c.name)> <pp(c.\type)>" | CQLColumnDefinition c <- columns ])>";
  
str pp(cDrop(list[str] columnNames))
  = " DROP <intercalate(" ", columnNames)>";
  
str pp(cWith(map[str, CQLValue] options))
  = ppWith(options);

str ppColumns(list[CQLColumnDefinition] cols, CQLPrimaryKey pk)
  = intercalate(",\n  ", [ pp(c) | CQLColumnDefinition c <- cols ] + [ "(<pp(pk)>)" ]);

str pp(cPrimaryKey(list[str] pk, clusteringColumns=list[str] cols))
  = "<pks><cols != [] ? ", " + intercalate(", ", cols) : "">"
  when 
    str pks := size(pk) == 1 ? pk[0] : "(<intercalate(", ", pk)>)";


str pp(cColumnDef(str name, CQLType \type, static=bool static, primaryKey=bool pk))
  = "<ppId(name)> <pp(\type)><static ? " STATIC" : " "><pk ? " PRIMARY KEY" : " ">";
 
 
str ppINE(bool b) = b ? " IF NOT EXISTS" : "";
str ppIE(bool b) = b ? " IF EXISTS" : "";

str ppWith(map[str, CQLValue] with) 
  = with() == () ? "" 
  : " WITH <intercalate(" AND ", [ "<k> = <pp(with[k])>" | str k <- with ])>";

  //| cDropKeySpace(str name, bool ifExists=false)
  //| 
  //| cAlterTable(str name, CQLAlterTableInstruction instruction)
  //| cDropTable(str name, bool ifExists=false)
  //| cTruncate(str name)
  //| cCreateType(str name, lrel[str name, CQLType \type] fields, bool ifNotExists=false)
  //| cAlterType(str name, CQLAlterTypeModification modification)
  //| cDropType(str name, bool ifExists=false)
  


str pp(cColumn(str name)) = ppId(name);

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
  = as == "" ? pp(e) : "<pp(e)> AS <ppId(as)>";

str pp(cOrder(str name, bool asc)) = "<name> <asc ? "ASC" : "DESC">";

/*
 * Expressions
 */

test bool smokePPExpr(CQLExpr e) {
  println(pp(e));
  return true;
}

str pp(cColumn(str name)) = ppId(name);
str pp(cTerm(CQLValue val)) = pp(val);
str pp(cCast(CQLExpr arg, CQLType \type)) = "CAST(<pp(arg)> AS <pp(\type)>)";
str pp(cCall(str name, list[CQLExpr] args)) = "<name>(<intercalate(", ", [ pp(a) | CQLExpr a <- args ])>)";
str pp(cCount()) = "COUNT(*)";

str pp(cUMinus(CQLExpr arg)) = "-(<pp(arg)>)";
str pp(cPlus(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> + <pp(rhs)>";
str pp(cMinus(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> - <pp(rhs)>";
str pp(cTimes(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> * <pp(rhs)>";
str pp(cDiv(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> / <pp(rhs)>";
str pp(cMod(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> % <pp(rhs)>";

str pp(cEq(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> = <pp(rhs)>";
str pp(cNeq(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> != <pp(rhs)>";
str pp(cLeq(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> \<= <pp(rhs)>";
str pp(cGeq(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> \>= <pp(rhs)>";
str pp(cLt(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> \< <pp(rhs)>";
str pp(cGt(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> \> <pp(rhs)>";
str pp(cIn(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> IN <pp(rhs)>";
str pp(cContains(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> CONTAINS <pp(rhs)>";
str pp(cContainsKey(CQLExpr lhs, CQLExpr rhs)) = "<pp(lhs)> CONTAINS KEY <pp(rhs)>";

str pp(cBindMarker(name = str name))
  = name == "" ? "?" : ":<name>";
  
str pp(cTypeHint(CQLType t, CQLExpr e)) = "(<pp(t)>)<pp(e)>";

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

str pp(cString(str s)) = "\'<escape(s, ("\'": "\'\'"))>\'";

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
  = "{<intercalate(", ", [ "<k>: <pp(m[k])>" | str k <- m ])>}";
  
