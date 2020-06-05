module lang::typhonql::neo4j::Neo

import util::Maybe;

data NeoStat
  = matchQuery(Match match)
  | matchUpdate(Maybe[Match] updateMatch, UpdateClause updateClause)
  ;

data Match
	= match(list[Pattern] patterns, list[Clause] clauses, list[NeoExpr] exprs)
	;  
  
data UpdateClause
	= create(Pattern pattern)
  	;
 	
data Pattern
	= pattern(NodePattern nodePattern, list[RelationshipPattern] rels)
	; 
	
data NodePattern
	= nodePattern(str var, list[str] labels, list[Property] properties);
	
data RelationshipPattern
	= relationshipPattern(Direction dir, str var, str label, list[Property] properties, NodePattern nodePattern);
	
data Direction
	= doubleArrow(); 
 
data Set
  = \set(str property, NeoExpr expr);
  
data NeoExpr
  = property(str \node, str name) // NB: always qualified
  | property(str name) // only for use in update
  | lit(Value val)
  | named(NeoExpr arg, str as) // p.name as x1
  | placeholder(str name = "") // for representing ? or :name 
  | not(NeoExpr arg) 
  | neg(NeoExpr arg) 
  | pos(NeoExpr arg) 
  | mul(NeoExpr lhs, NeoExpr rhs) 
  | div(NeoExpr lhs, NeoExpr rhs) 
  | add(NeoExpr lhs, NeoExpr rhs) 
  | sub(NeoExpr lhs, NeoExpr rhs) 
  | equ(NeoExpr lhs, NeoExpr rhs) 
  | neq(NeoExpr lhs, NeoExpr rhs) 
  | leq(NeoExpr lhs, NeoExpr rhs) 
  | geq(NeoExpr lhs, NeoExpr rhs) 
  | lt(NeoExpr lhs, NeoExpr rhs) 
  | gt(NeoExpr lhs, NeoExpr rhs) 
  | like(NeoExpr lhs, NeoExpr rhs) 
  | or(NeoExpr lhs, NeoExpr rhs) 
  | and(NeoExpr lhs, NeoExpr rhs) 
  | notIn(NeoExpr arg, list[Value] vals)
  | \in(NeoExpr arg, list[Value] vals)
  | fun(str name, list[NeoExpr] args)
  ;

data Clause
  = where(list[NeoExpr] exprs)
  | groupBy(list[NeoExpr] exprs) // for now just property(t,n) is supported
  | having(list[NeoExpr] exprs)
  | orderBy(list[NeoExpr] exprs, Dir dir)
  | limit(NeoExpr expr)
  ; 
  
data Dir
 = asc()
 | desc()
 ;

  
data Property
  = property(str name, NeoExpr expr);


// https://dev.mysql.com/doc/refman/8.0/en/data-types.html  
data PropertyType
  = varchar(int size)
  | char(int size)
  | text()
  | integer()
  | bigint()
  | float()
  | double()
  | blob()
  | point()
  | polygon()
  | date()
  | dateTime()
  ; 
  
data Value
  = text(str strVal)
  | decimal(real realVal)
  | integer(int intVal)
  | boolean(bool boolVal)
  | point(real x, real y)
  | polygon(list[lrel[real, real]] segs)
  | dateTime(datetime dateTimeVal)
  | date(datetime dateVal)
  | placeholder(str name="")
  | null()
  ;


