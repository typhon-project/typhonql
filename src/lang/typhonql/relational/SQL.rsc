module lang::typhonql::relational::SQL


data SQLStat
  = create(str table, list[Column] cols, list[TableConstraint] constraints)
  | \insert(str table, list[str] colNames, list[Value] values)
  | update(str table, list[Set] sets, list[Clause] clauses)
  | select(list[SQLExpr] exprs, list[As] tables, list[Clause] clauses)
  | alterTable(str table, list[Alter] alters)
  ;

data Set
  = \set(str column, SQLExpr expr);

  
data Alter
  = addConstraint(TableConstraint constraint);

  
data SQLExpr
  = column(str table, str name) // NB: always qualified
  | lit(Value val)
  | not(SQLExpr arg) 
  | neg(SQLExpr arg) 
  | pos(SQLExpr arg) 
  | equ(SQLExpr lhs, SQLExpr rhs) 
  | neq(SQLExpr lhs, SQLExpr rhs) 
  | leq(SQLExpr lhs, SQLExpr rhs) 
  | geq(SQLExpr lhs, SQLExpr rhs) 
  | lt(SQLExpr lhs, SQLExpr rhs) 
  | gt(SQLExpr lhs, SQLExpr rhs) 
  | like(SQLExpr lhs, SQLExpr rhs) 
  | or(SQLExpr lhs, SQLExpr rhs) 
  | and(SQLExpr lhs, SQLExpr rhs) 
  ;


data As
  = as(str table, str name);

data Clause
  = where(list[SQLExpr] exprs)
  | groupBy(list[SQLExpr] exprs) // for now just column(t,n) is supported
  | having(list[SQLExpr] exprs)
  | orderBy(list[SQLExpr] exprs, Dir dir)
  | limit(SQLExpr expr)
  ; 
  
data Dir
 = asc()
 | desc()
 ;

  
data Column
  = column(str name, ColumnType \type, list[ColumnConstraint] constraints);

data ColumnConstraint
  = notNull()
  | unique()
  ;

data TableConstraint
  = primaryKey(str column)
  | foreignKey(str column, str parent, str key, OnDelete onDelete)
  ;
  
data OnDelete
  = cascade()
  | nothing()
  ;

// https://dev.mysql.com/doc/refman/8.0/en/data-types.html  
data ColumnType
  = char(int size)
  | varchar(int size)
  | text()
  | integer()
  | float()
  | double()
  | blob()
  | date()
  | dateTime()
  ; 
  
data Value
  = text(str strVal)
  | decimal(real realVal)
  | integer(int intVal)
  | boolean(bool boolVal)
  | null()
  ;



