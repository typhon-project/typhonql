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

module lang::typhonql::cassandra::CQL


data CQLStat
  = cCreateKeySpace(str name, bool ifNotExists=false, map[str,CQLValue] with=())
  | cAlterKeySpace(str name, map[str,CQLValue] with=()) 
  | cDropKeySpace(str name, bool ifExists=false)
  | cCreateTable(str name, list[CQLColumnDefinition] columns, CQLPrimaryKey primaryKey=cNoPrimaryKey(), bool ifNotExists=false, map[str, CQLValue] with=())
  | cAlterTable(str name, CQLAlterTableInstruction instruction)
  | cDropTable(str name, bool ifExists=false)
  | cTruncate(str name)
  | cCreateType(str name, lrel[str name, CQLType \type] fields, bool ifNotExists=false)
  | cAlterType(str name, CQLAlterTypeModification modification)
  | cDropType(str name, bool ifExists=false)
  
  | cSelect(list[CQLSelectClause] selectClauses, str tableName, list[CQLExpr] wheres, 
      list[str] groupBy=[],
      list[CQLOrderBy] orderBy=[], 
      CQLExpr perPartitionLimit=cTerm(cInteger(-1)),
      CQLExpr limit=cTerm(cInteger(-1)),
      CQLExpr offset=cTerm(cInteger(0)),
      bool allowFiltering=false, 
      bool distinct=false, 
      bool json=false)
      
  | cInsert(str name, list[str] columnNames, list[CQLExpr] values, 
       bool ifNotExists=false, 
       list[CQLUpdateParam] using=[])
  
  | cUpdate(str name, list[CQLAssignment] sets, list[CQLExpr] wheres,
      list[CQLUpdateParam] using=[],
      bool ifExists=false,
      list[CQLExpr] conditions=[])
      
  | cDelete(str name, list[CQLExpr] wheres,
      list[CQLSimpleSelection] columnSelection=[],
      list[CQLUpdateParam] using=[],
      bool ifExists=false,
      list[CQLExpr] conditions=[])
  ;

data CQLUpdateParam
  = cTimestamp(CQLExpr microSeconds)
  | cTTL(CQLExpr seconds)
  ;

data CQLSimpleSelection
 = cColumn(str name)
 | cIndexed(str name, CQLExpr index)
 | cSubfield(str name, str field)
 ;

data CQLAssignment
  = cSimple(CQLSimpleSelection selection, CQLExpr term)
  | cIncr(str target, str other, CQLExpr term)
  | cDecr(str target, str other, CQLExpr term)
  | cConcat(str target, CQLValue collection, str other)
  ;

data CQLSelectClause
  = cStar()
  | cSelector(CQLExpr, str as="")
  ;
  
data CQLOrderBy
  = cOrder(str name, bool asc);

data CQLExpr
  = cColumn(str name)
  | cTerm(CQLValue val)
  | cCast(CQLExpr arg, CQLType \type)
  | cCall(str name, list[CQLExpr] args)
  | cCount()
  | cUMinus(CQLExpr arg)
  | cPlus(CQLExpr lhs, CQLExpr rhs)
  | cMinus(CQLExpr lhs, CQLExpr rhs)
  | cTimes(CQLExpr lhs, CQLExpr rhs)
  | cDiv(CQLExpr lhs, CQLExpr rhs)
  | cMod(CQLExpr lhs, CQLExpr rhs)
  | cEq(CQLExpr lhs, CQLExpr rhs)
  | cNeq(CQLExpr lhs, CQLExpr rhs)
  | cLeq(CQLExpr lhs, CQLExpr rhs)
  | cGeq(CQLExpr lhs, CQLExpr rhs)
  | cLt(CQLExpr lhs, CQLExpr rhs)
  | cGt(CQLExpr lhs, CQLExpr rhs)
  | cIn(CQLExpr lhs, CQLExpr rhs)
  | cContains(CQLExpr lhs, CQLExpr rhs)
  | cContainsKey(CQLExpr lhs, CQLExpr rhs)
  | cBindMarker(str name = "")
  | cTypeHint(CQLType \type, CQLExpr arg)
  ;
  
  

data CQLColumnDefinition
  = cColumnDef(str name, CQLType \type, bool static=false, bool primaryKey=false);

data CQLPrimaryKey
  = cPrimaryKey(list[str] partitionKey, list[str] clusteringColumns=[])
  | cNoPrimaryKey()
  ;

data CQLAlterTableInstruction
  = cAdd(list[CQLColumnDefinition] columns)
  | cDrop(list[str] columnNames)
  | cWith(map[str, CQLValue] options)
  ;
  
data CQLAlterTypeModification
  = cAdd(str name, CQLType \type)
  | cRename(map[str old, str new] renamings)
  ;
  

// https://cassandra.apache.org/doc/latest/cql/types.html
data CQLType
  = cASCII()
  | cBigInt()
  | cBlob()
  | cBoolean()
  | cCounter()
  | cDate()
  | cDecimal()
  | cDouble()
  | cDuration()
  | cFloat()
  | cInet()
  | cInt()
  | cSmallInt()
  | cText()
  | cTime()
  | cTimestamp()
  | cTimeUUID()
  | cTinyInt()
  | cUUID()
  | cVarchar()
  | cVarint()
  | cMap(CQLType keyType, CQLType valueType)
  | cSet(CQLType elementType)
  | cList(CQLType listType)
  | cUserDefined(str name, str keySpace="")
  | cTuple(list[CQLType] \types)
  | cFrozen(CQLType arg)
  ;
  
data CQLValue
  = cString(str strVal)
  //| cblob() // todo
  | cInteger(int intVal)
  | cBoolean(bool boolVal)
  | cFloat(real realVal)
  //| cduration()
  | cUUID(str uuidVal)
  | cMap(map[CQLValue, CQLValue] keyVals)
  | cSet(set[CQLValue] setVals)
  | cList(list[CQLValue] listVals)
  | cTuple(list[CQLValue] tupleVals)
  | cUserDefined(map[str field, CQLValue \value] udtValues)
  | cNull()
  ;
  
