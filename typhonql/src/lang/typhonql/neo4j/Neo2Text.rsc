module lang::typhonql::neo4j::Neo2Text

import lang::typhonql::neo4j::Neo;
import lang::typhonml::Util;
import List;
import String;
import DateTime;
import util::Maybe;

// NB: we use ` to escape identifiers, however, this is not ANSI SQL, but works in MySQL
str q(str x) = "`<x>`";


str pp(list[NeoStat] stats) = intercalate("\n\n", [ pp(s) | NeoStat s <- stats ]);

str pp(map[Place,list[NeoStat]] placed)
  = intercalate("\n", [ "<p>: <pp(placed[p])>" | Place  p <- placed ]); 

// NeoStat

str pp(matchUpdate(Maybe[Match] updateMatch, UpdateClause uc))
  = "<just(m) := updateMatch ? pp(m) : "">
    '<pp(uc)>";  
    
    
str pp(matchQuery(Match m))
  = pp(m);  
    
str pp(create(Pattern pattern))
  = "create (<pp(pattern)>)";
  
str pp(pattern(nodePattern, rels))
	= "<pp(nodePattern)>";
	
str pp(nodePattern(str var, str label, list[Property] props))
	= "<var> : <label><!isEmpty(props)?" { <intercalate(", ", [pp(p) | p <- props])> }":"">";
	
str pp(property(str name, NeoExpr expr))
	="<q(name)> : <pp(expr)>";

str pp(match(list[Pattern] patterns, list[Clause] cs, list[NeoExpr] es))
  = "match (<intercalate(", ", [ pp(p) | Pattern p <- patterns ])>)
    '<intercalate("\n", [ pp(c) | Clause c <- cs ])>
    'return <intercalate(", ", [ pp(e) | NeoExpr e <- es ])>"
    ;  

str pp(match(list[NeoExpr] es, list[As] as, list[Clause] cs))
  = "match (<intercalate(", ", [ pp(a) | As a <- as ])>)
    '<intercalate("\n", [ pp(c) | Clause c <- cs ])>
    'return <intercalate(", ", [ pp(e) | NeoExpr e <- es ])>"
    ;  

str pp(create(str t, list[Column] cs, list[TableConstraint] cos))
  = "create table <q(t)> (
    '  <intercalate(",\n", [ pp(c) | Column c <- cs ] + [ pp(c) | TableConstraint c <- cos ])>
    ');";

str pp(rename(str t, str newName))
  = "rename table <q(t)> to <q(newName)>;";

str pp(create(str t, list[str] ps, list[NeoExpr] vs))
  = "create (n:<q(t)> { <intercalate(", ", [ "<q(ps[i])> : <pp(vs[i])>" | i <- [0..size(ps)]])> })";
  

str pp(update(str t, list[Set] ss, list[Clause] cs))
  = "update <q(t)> set <intercalate(", ", [ pp(s) | Set s <- ss ])>
    '<intercalate("\n", [ pp(c) | Clause c <- cs ])>;";
  
str pp(delete(str t, list[Clause] cs))
  = "delete from <q(t)> 
    '<intercalate("\n", [ pp(c) | Clause c <- cs ])>;";

str pp(deleteJoining(list[str] tables, list[Clause] cs)) 
  = "delete <intercalate(", ", [ q(t) | str t <- tables ])> 
    'from <intercalate(" inner join ", [ q(t) | str t <- tables ])>
    '<intercalate("\n", [ pp(c) | Clause c <- cs ])>";

str pp(alterTable(str t, list[Alter] as))
  = "alter table <q(t)>
    '<intercalate(",\n", [ pp(a) | Alter a <- as ])>;";


str pp(dropTable(list[str] tables, bool ifExists, list[DropOption] options))
  = "drop table <ifExists ? "if exists " : ""><intercalate(", ", [ q(t) | str t <- tables])> <intercalate(", ", [ pp(opt) | DropOption opt <- options ])>;";

// Alter

str pp(addConstraint(TableConstraint c))
  = "add constraint 
    '<pp(c)>";
    
str pp(dropConstraint(str name))
  = "drop constraint <q(name)>";
    
str pp(addColumn(column(str name, ColumnType \type, list[ColumnConstraint] constraints)))
  = "add <q(name)> <pp(\type)>";

str pp(dropColumn(str name))
  = "drop column <q(name)>";
  

str pp(renameColumn(column(str name, ColumnType \type, list[ColumnConstraint] _), str newName))
  = "change column <q(name)> <q(newName)> <pp(\type)>";  

// As

str pp(as(str t, str x)) = "<x>:<t>";

// Set

str pp(\set(str c, NeoExpr e)) = "<q(c)> = <pp(e)>";


// NeoExpr

str pp(property(str \node, str name)) = "<\node>.<q(name)>";
str pp(named(NeoExpr e, str as)) = "<pp(e)> as <q(as)>";
str pp(lit(Value val)) = pp(val);
str pp(placeholder(name = str name)) =  name == "" ? "?" : "${<name>}";
str pp(not(NeoExpr arg)) = "not (<pp(arg)>)";
str pp(neg(NeoExpr arg)) = "-(<pp(arg)>)"; 
str pp(pos(NeoExpr arg)) = "+(<pp(arg)>)";
str pp(mul(NeoExpr lhs, NeoExpr rhs)) = "(<pp(lhs)>) * (<pp(rhs)>)"; 
str pp(div(NeoExpr lhs, NeoExpr rhs)) = "(<pp(lhs)>) / (<pp(rhs)>)"; 
str pp(add(NeoExpr lhs, NeoExpr rhs)) = "(<pp(lhs)>) + (<pp(rhs)>)"; 
str pp(sub(NeoExpr lhs, NeoExpr rhs)) = "(<pp(lhs)>) - (<pp(rhs)>)"; 
str pp(equ(NeoExpr lhs, NeoExpr rhs)) = "(<pp(lhs)>) = (<pp(rhs)>)"; 
str pp(neq(NeoExpr lhs, NeoExpr rhs)) = "(<pp(lhs)>) \<\> (<pp(rhs)>)"; 
str pp(leq(NeoExpr lhs, NeoExpr rhs)) = "(<pp(lhs)>) \<= (<pp(rhs)>)"; 
str pp(geq(NeoExpr lhs, NeoExpr rhs)) = "(<pp(lhs)>) \>= (<pp(rhs)>)"; 
str pp(lt(NeoExpr lhs, NeoExpr rhs)) = "(<pp(lhs)>) \< (<pp(rhs)>)"; 
str pp(gt(NeoExpr lhs, NeoExpr rhs)) = "(<pp(lhs)>) \> (<pp(rhs)>)"; 
str pp(like(NeoExpr lhs, NeoExpr rhs)) = "(<pp(lhs)>) like (<pp(rhs)>)"; 
str pp(or(NeoExpr lhs, NeoExpr rhs)) = "(<pp(lhs)>) or (<pp(rhs)>)"; 
str pp(and(NeoExpr lhs, NeoExpr rhs)) = "(<pp(lhs)>) and (<pp(rhs)>)";
str pp(notIn(NeoExpr arg, list[Value] vals)) 
  = "(<pp(arg)>) not in (<intercalate(", ", [ pp(v) | Value v <- vals])>)";
str pp(\in(NeoExpr arg, list[Value] vals)) 
  = "(<pp(arg)>) in (<intercalate(", ", [ pp(v) | Value v <- vals])>)";

str pp(fun(str name, vals)) = "<name>(<intercalate(", ", [pp(v) | v <- vals])>)";

str pp(NeoExpr::placeholder(name = str name)) = "${<name>}";

// Clause

str pp(where(list[NeoExpr] es)) = "where <intercalate(" and ", [ pp(e) | NeoExpr e <- es ])>"; 

str pp(groupBy(list[NeoExpr] es)) = "group by <intercalate(", ", [ pp(e) | NeoExpr e <- es ])>"; 

str pp(having(list[NeoExpr] es)) = "having <intercalate(", ", [ pp(e) | NeoExpr e <- es ])>"; 

str pp(orderBy(list[NeoExpr] es, Dir d)) = "order by <intercalate(", ", [ pp(e) | NeoExpr e <- es ])> <pp(d)>"; 

str pp(limit(NeoExpr e)) = "limit <pp(e)>"; 

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

str pp(dateTime(datetime d)) = "\'<printDate(d, "YYYY-MM-dd HH:mm:ss")>\'";

str pp(date(datetime d)) = "\'<printDate(d, "YYYY-MM-dd")>\'";

str pp(point(real x, real y)) = "PointFromText(\'POINT(<x> <y>)\', 4326)";

str pp(polygon(list[lrel[real, real]] segs)) 
  = "PolyFromText(\'POLYGON(<intercalate(", ", [ seg2str(s) | s <- segs ])>)\', 4326)";

str seg2str(lrel[real,real] seg)  
  = "(<intercalate(", ", [ "<x> <y>" | <real x, real y> <- seg ])>)";

str pp(null()) = "null";

str pp(Value::placeholder(name = str name)) = "${<name>}";

// TableConstraint

str pp(primaryKey(str c)) = "primary key (<q(c)>)";

str pp(foreignKey(str c, str p, str k, OnDelete od)) 
  = "foreign key (<q(c)>) 
    '  references <q(p)>(<q(k)>)<pp(od)>";


str pp(index(_, spatial(), list[str] columns))
    = intercalate(", ", ["spatial index(<q(c)>)" | c <- columns]);

// ColumnConstraint

str pp(notNull()) = "not null";

str pp(unique()) = "unique";


// ColumnType

str pp(char(int size)) = "char(<size>)";
str pp(varchar(int size)) = "varchar(<size>)";
str pp(text()) = "text";
str pp(integer()) = "integer";
str pp(float()) = "float";
str pp(double()) = "double";
str pp(blob()) = "blob";
str pp(date()) = "date";
str pp(dateTime()) = "datetime";
str pp(point()) = "point";
str pp(polygon()) = "polygon";

