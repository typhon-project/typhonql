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

str pp(matchUpdate(just(match(list[Pattern] ps, list[Clause] cs, list[NeoExpr] es)), UpdateClause uc))
  = "match <intercalate(", ", [ pp(p) | Pattern p <- ps ])>
    '<intercalate("\n", [ pp(c) | Clause c <- cs ])>
    '<pp(uc)>
    'return <intercalate(", ", [ pp(e) | NeoExpr e <- es ])>"
    ;  

str pp(matchUpdate(nothing(), UpdateClause uc))
  = pp(uc);  
    
str pp(matchQuery(match(list[Patterns] ps, list[Clause] cs, list[NeoExpr] es)))
  = "match <intercalate(", ", [ pp(p) | Pattern p <- ps ])>
    '<intercalate("\n", [ pp(c) | Clause c <- cs ])>
    'return <intercalate(", ", [ pp(e) | NeoExpr e <- es ])>"
    ;  
    
str pp(create(Pattern pattern))
  = "create <pp(pattern)>";
  
str pp(pattern(nodePattern, rels))
	= "<pp(nodePattern)><intercalate(" ", [pp(r) | r <- rels])>";
	
str pp(relationshipPattern(Direction dir, str var, str label, list[Property] props, NodePattern nodePattern))
	= "-[<var>:<label>]-\><pp(nodePattern)>";
	
str pp(nodePattern(str var, list[str] labels, list[Property] props))
	= "(<var> <isEmpty(labels)?"":":" + intercalate(":", labels)><!isEmpty(props)?" { <intercalate(", ", [pp(p) | p <- props])> }":"">)";
	
str pp(property(str name, NeoExpr expr))
	="<q(name)> : <pp(expr)>";

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

