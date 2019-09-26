module lang::typhonql::relational::SQL2Text

import lang::typhonql::relational::SQL;
import lang::typhonml::Util;
import List;
import String;

// NB: we use ` to escape identifiers, however, this is not ANSI SQL, but works in MySQL
str q(str x) = "`<x>`";


str pp(list[SQLStat] stats) = intercalate("\n\n", [ pp(s) | SQLStat s <- stats ]);

str pp(map[Place,list[SQLStat]] placed)
  = intercalate("\n", [ "<p>: <pp(placed[p])>" | Place p <- placed ]); 

// SQLStat

str pp(create(str t, list[Column] cs, list[TableConstraint] cos))
  = "create table <q(t)> (
    '  <intercalate(",\n", [ pp(c) | Column c <- cs ] + [ pp(c) | TableConstraint c <- cos ])>
    ');";

str pp(\insert(str t, list[str] cs, list[Value] vs))
  = "insert into <q(t)> (<intercalate(", ", [ q(c) | str c <- cs ])>) 
    'values (<intercalate(", ", [ pp(v) | Value v <- vs ])>);";
  

str pp(update(str t, list[Set] ss, list[Clause] cs))
  = "update <q(t)> set <intercalate(", ", [ pp(s) | Set s <- ss ])>
    '<intercalate("\n", [ pp(c) | Clause c <- cs ])>;";
  
str pp(delete(str t, list[Clause] cs))
  = "delete from <q(t)> 
    '<intercalate("\n", [ pp(c) | Clause c <- cs ])>;";

str pp(select(list[SQLExpr] es, list[As] as, list[Clause] cs))
  = "select <intercalate(", ", [ pp(e) | SQLExpr e <- es ])> 
    'from <intercalate(", ", [ pp(a) | As a <- as ])>
    '<intercalate("\n", [ pp(c) | Clause c <- cs ])>;";  

str pp(alterTable(str t, list[Alter] as))
  = "alter table <q(t)>
    '<intercalate(",\n", [ pp(a) | Alter a <- as ])>;";


str pp(dropTable(list[str] tables, bool ifExists, list[DropOption] options))
  = "drop table <ifExists ? "if exists " : ""><intercalate(", ", [ q(t) | str t <- tables])> <intercalate(", ", [ pp(opt) | DropOption opt <- options ])>;";

str pp(DropOption::restrict()) = "restrict";

str pp(DropOption::cascade()) = "cascade";

// Alter

str pp(addConstraint(TableConstraint c))
  = "add constraint 
    '<pp(c)>";


// As

str pp(as(str t, str x)) = "<q(t)> as <q(x)>";

// Set

str pp(\set(str c, SQLExpr e)) = "<q(c)> = <pp(e)>";


// SQLExpr

str pp(column(str table, str name)) = "<q(table)>.<q(name)>";
str pp(lit(Value val)) = pp(val);
str pp(placeholder()) = "?";
str pp(not(SQLExpr arg)) = "not (<pp(arg)>)";
str pp(neg(SQLExpr arg)) = "-(<pp(arg)>)"; 
str pp(pos(SQLExpr arg)) = "+(<pp(arg)>)";
str pp(mul(SQLExpr lhs, SQLExpr rhs)) = "(<pp(lhs)>) * (<pp(rhs)>)"; 
str pp(div(SQLExpr lhs, SQLExpr rhs)) = "(<pp(lhs)>) / (<pp(rhs)>)"; 
str pp(add(SQLExpr lhs, SQLExpr rhs)) = "(<pp(lhs)>) + (<pp(rhs)>)"; 
str pp(sub(SQLExpr lhs, SQLExpr rhs)) = "(<pp(lhs)>) - (<pp(rhs)>)"; 
str pp(equ(SQLExpr lhs, SQLExpr rhs)) = "(<pp(lhs)>) = (<pp(rhs)>)"; 
str pp(neq(SQLExpr lhs, SQLExpr rhs)) = "(<pp(lhs)>) \<\> (<pp(rhs)>)"; 
str pp(leq(SQLExpr lhs, SQLExpr rhs)) = "(<pp(lhs)>) \<= (<pp(rhs)>)"; 
str pp(geq(SQLExpr lhs, SQLExpr rhs)) = "(<pp(lhs)>) \>= (<pp(rhs)>)"; 
str pp(lt(SQLExpr lhs, SQLExpr rhs)) = "(<pp(lhs)>) \< (<pp(rhs)>)"; 
str pp(gt(SQLExpr lhs, SQLExpr rhs)) = "(<pp(lhs)>) \> (<pp(rhs)>)"; 
str pp(like(SQLExpr lhs, SQLExpr rhs)) = "(<pp(lhs)>) like (<pp(rhs)>)"; 
str pp(or(SQLExpr lhs, SQLExpr rhs)) = "(<pp(lhs)>) or (<pp(rhs)>)"; 
str pp(and(SQLExpr lhs, SQLExpr rhs)) = "(<pp(lhs)>) and (<pp(rhs)>)";


// Clause

str pp(where(list[SQLExpr] es)) = "where <intercalate(", ", [ pp(e) | SQLExpr e <- es ])>"; 

str pp(groupBy(list[SQLExpr] es)) = "group by <intercalate(", ", [ pp(e) | SQLExpr e <- es ])>"; 

str pp(having(list[SQLExpr] es)) = "having <intercalate(", ", [ pp(e) | SQLExpr e <- es ])>"; 

str pp(orderBy(list[SQLExpr] es, Dir d)) = "order by <intercalate(", ", [ pp(e) | SQLExpr e <- es ])> <pp(d)>"; 

str pp(limit(SQLExpr e)) = "limit <pp(e)>"; 

// Dir

str pp(asc()) = "asc";

str pp(desc()) = "desc";


// Column
    
str pp(column(str c, ColumnType t, list[ColumnConstraint] cos))
  = "<q(c)> <intercalate(" ", [pp(t)] + [ pp(co) | ColumnConstraint co <- cos ])>";
  

// Value

str pp(text(str x)) = "\'<escape(x, ("\'": "\'\'"))>\'";

str pp(decimal(real x)) = "<x>";

str pp(integer(int x)) = "<x>";

str pp(boolean(bool b)) = "<b>";

str pp(dateTime(datetime d)) = printDate(d, "\'YYYY-MM-dd HH:mm:ss\'");

str pp(null()) = "null";

// TableConstraint

str pp(primaryKey(str c)) = "primary key (<q(c)>)";

str pp(foreignKey(str c, str p, str k, OnDelete od)) 
  = "foreign key (<q(c)>) 
    '  references <q(p)>(<q(k)>)<pp(od)>";


// OnDelete

str pp(OnDelete::cascade()) = " on delete cascade";

str pp(OnDelete::nothing()) = "";


// ColumnConstraint

str pp(notNull()) = "not null";

str pp(unique()) = "unique";

// ColumnType

str pp(char(int size)) = "char(<size>)";
str pp(varchar(int size)) = "varchar(<size>)";
str pp(text()) = "text";
str pp(integer()) = "int";
str pp(float()) = "float";
str pp(double()) = "double";
str pp(blob()) = "blob";
str pp(date()) = "date";
str pp(dateTime()) = "datetime";

