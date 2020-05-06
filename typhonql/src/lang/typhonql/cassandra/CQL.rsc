module lang::typhonql::cassandra::CQL


data CQLStat
  = cCreateKeySpace(str name, bool ifNotExists=false, map[str,value] with=())
  | cDropKeySpace(str name, bool ifExists=false)
  | cCreateTable(str name, list[CQLColumnDefinition] columns, CQLPrimaryKey primaryKey, bool ifNotExists=false, map[str, value] with=())
  | cAlterTable(str name, CQLAlterTableInstruction instruction)
  | cDropTable(str name, bool ifExists=false)
  | cTruncate(str name)
  | cCreateType(str name, lrel[str name, CQLType \type] fields, bool ifNotExists=false)
  | cAlterType(str name, CQLAlterTypeModification modification)
  | cDropType(str name, bool ifExists=false)
  
  | cSelect(list[CQLSelectClause] selectClauses, str tableName, list[CQLExpr] wheres, 
      list[str] groupBy=[],
      list[CQLOrderBy] orderBy=[], 
      int perPartitionLimit=-1,
      int limit=-1,
      bool allowFiltering=false, 
      bool distinct=false, 
      bool json=false)
      
  | cInsert(str name, list[str] columnNames, list[CQLValue] values, 
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
  = cTimestamp(int microSeconds)
  | cTTL(int seconds)
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
  | cEq(CQLExpr lhs, CQLExpr rhs)
  | cNeq(CQLExpr lhs, CQLExpr rhs)
  | cLeq(CQLExpr lhs, CQLExpr rhs)
  | cGeq(CQLExpr lhs, CQLExpr rhs)
  | cLt(CQLExpr lhs, CQLExpr rhs)
  | cGt(CQLExpr lhs, CQLExpr rhs)
  | cIn(CQLExpr lhs, CQLExpr rhs)
  | cContains(CQLExpr lhs, CQLExpr rhs)
  | cContainsKey(CQLExpr lhs, CQLExpr rhs)
  ;
  
  

data CQLColumnDefinition
  = cColumnDef(str name, CQLType \type, bool static=false, bool primaryKey=false);

data CQLPrimaryKey
  = cPrimaryKey(list[str] partitionKey, list[str] clusteringColumns=[]);

data CQLAlterTableInstruction
  = cAdd(lrel[str name, CQLType \type] columns)
  | cDrop(list[str] columnNames)
  | cWith(map[str, value] options)
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
  ;
  
