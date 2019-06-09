module lang::typhonql::relational::SQL

data SQLStat
  = create(str table, list[Column] cols, list[TableConstraint] constraints)
  | \insert(str table, list[value] values)
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
