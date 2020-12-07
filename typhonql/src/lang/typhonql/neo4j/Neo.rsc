module lang::typhonql::neo4j::Neo

import util::Maybe;

data NeoStat
  = nMatchQuery(list[NeoMatch] matches, list[NeoExpr] returnExprs)
  | nMatchUpdate(Maybe[NeoMatch] updateMatch, NeoUpdateClause updateClause, list[NeoExpr] returnExprs)
  ;

data NeoMatch
	= nMatch(list[NeoPattern] patterns, list[NeoClause] clauses)
	| nCallYield(str name, list[NeoExpr] args, list[str] procedureResults)
	;  
  
data NeoUpdateClause
	= nCreate(NeoPattern pattern)
	| nDetachDelete(list[NeoExpr] exprs)
	| nDelete(list[NeoExpr] exprs)
	| nSet(list[NeoSetItem] setitems)
  	;
 	
data NeoPattern
	= nPattern(NeoNodePattern nodePattern, list[NeoRelationshipPattern] rels)
	; 
	
data NeoNodePattern
	= nNodePattern(str var, list[str] labels, list[NeoProperty] properties);
	
data NeoRelationshipPattern
	= nRelationshipPattern(NeoDirection dir, str var, str label, list[NeoProperty] properties, NeoNodePattern nodePattern);
	
data NeoDirection
	= nDoubleArrow(); 
 
data NeoSetItem
  = nSetEquals(str variable, NeoExpr expr)
  | nSetPlusEquals(str variable, NeoExpr expr);
  
data NeoExpr
  = nProperty(str \node, str name) // NB: always qualified
  | nProperty(str name) // only for use in update
  | nLit(NeoValue val)
  | nMapLit(map[str, NeoExpr] exprs)
  | nVariable(str name)
  | nNamed(NeoExpr arg, str as) // p.name as x1
  | nPlaceholder(str name = "") // for representing ? or :name 
  | nNot(NeoExpr arg) 
  | nNeg(NeoExpr arg) 
  | nPos(NeoExpr arg) 
  | nMul(NeoExpr lhs, NeoExpr rhs) 
  | nDiv(NeoExpr lhs, NeoExpr rhs) 
  | nAdd(NeoExpr lhs, NeoExpr rhs) 
  | nSub(NeoExpr lhs, NeoExpr rhs) 
  | nEqu(NeoExpr lhs, NeoExpr rhs) 
  | nNeq(NeoExpr lhs, NeoExpr rhs) 
  | nLeq(NeoExpr lhs, NeoExpr rhs) 
  | nGeq(NeoExpr lhs, NeoExpr rhs) 
  | nLt(NeoExpr lhs, NeoExpr rhs) 
  | nGt(NeoExpr lhs, NeoExpr rhs) 
  | nLike(NeoExpr lhs, NeoExpr rhs) 
  | nOr(NeoExpr lhs, NeoExpr rhs) 
  | nAnd(NeoExpr lhs, NeoExpr rhs) 
  | nNotIn(NeoExpr arg, list[NeoValue] vals)
  | nIn(NeoExpr arg, list[NeoValue] vals)
  | nFun(str name, list[NeoExpr] args)
  | nReaching(str edgeType, Maybe[NeoExpr] lower, Maybe[NeoExpr] upper, str from, str to)
  ;

data NeoClause
  = nWhere(list[NeoExpr] exprs)
  | nGroupBy(list[NeoExpr] exprs) // for now just property(t,n) is supported
  | nHaving(list[NeoExpr] exprs)
  | nOrderBy(list[NeoExpr] exprs, NeoDir dir)
  | nLimit(NeoExpr expr)
  | nOffset(NeoExpr expr)
  ; 
  
data NeoDir
 = nAsc()
 | nDesc()
 ;

  
data NeoProperty
  = nProperty(str name, NeoExpr expr);


data NeoPropertyType
  = nVarchar(int size)
  | nChar(int size)
  | nText()
  | nInteger()
  | nBigint()
  | nFloat()
  | nDouble()
  | nBlob()
  | nPoint()
  | nPolygon()
  | nDate()
  | nDateTime()
  ; 
  
data NeoValue
  = nText(str strVal)
  | nDecimal(real realVal)
  | nInteger(int intVal)
  | nBoolean(bool boolVal)
  | nPoint(real x, real y)
  | nPolygon(list[lrel[real, real]] segs)
  | nDateTime(datetime dateTimeVal)
  | nDate(datetime dateVal)
  | nPlaceholder(str name="")
  | nNull()
  ;


