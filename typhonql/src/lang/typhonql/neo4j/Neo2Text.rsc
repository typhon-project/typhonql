module lang::typhonql::neo4j::Neo2Text

import lang::typhonql::neo4j::Neo;
import lang::typhonml::Util;
import List;
import String;
import DateTime;
import util::Maybe;

// NB: we use ` to escape identifiers, however, this is not ANSI SQL, but works in MySQL
str q(str x) = "`<x>`";


str neopp(list[NeoStat] stats) = intercalate("\n\n", [ neopp(s) | NeoStat s <- stats ]);

str neopp(map[Place,list[NeoStat]] placed)
  = intercalate("\n", [ "<p>: <neopp(placed[p])>" | Place  p <- placed ]); 

// NeoStat

str neopp(matchUpdate(just(match(list[Pattern] ps, list[Clause] cs, list[NeoExpr] es)), UpdateClause uc))
  = "match <intercalate(", ", [ neopp(p) | Pattern p <- ps ])>
    '<intercalate("\n", [ neopp(c) | Clause c <- cs ])>
    '<neopp(uc)>
    '<isEmpty(es)?"":"return "><intercalate(", ", [ neopp(e) | NeoExpr e <- es ])>"
    ;  

str neopp(matchUpdate(nothing(), UpdateClause uc))
  = neopp(uc);  
    
str neopp(matchQuery(match(list[Pattern] ps, list[Clause] cs, list[NeoExpr] es)))
  = "match <intercalate(", ", [ neopp(p) | Pattern p <- ps ])>
    '<intercalate("\n", [ neopp(c) | Clause c <- cs ])>
    'return <intercalate(", ", [ neopp(e) | NeoExpr e <- es ])>"
    ;  
    
str neopp(create(Pattern pattern))
  = "create <neopp(pattern)>";
  
str neopp(detachDelete(list[NeoExpr] exprs))
  = "detach delete <intercalate(", ", [neopp(e) | e <- exprs])>";

str neopp(delete(list[NeoExpr] exprs))
  = "delete <intercalate(", ", [neopp(e) | e <- exprs])>";

str neopp(\set(list[SetItem] setItems))
  = "set <intercalate(", ", [neopp(i) | i <- setItems])>";
  
str neopp(setEquals(str variable, NeoExpr expr))
  = "<variable> = <neopp(expr)>";
  
str neopp(setPlusEquals(str variable, NeoExpr expr))
  = "<variable> += <neopp(expr)>";  
  
str neopp(pattern(nodePattern, rels))
	= "<neopp(nodePattern)><intercalate(" ", [neopp(r) | r <- rels])>";
	
str neopp(relationshipPattern(Direction dir, str var, str label, list[Property] props, NodePattern nodePattern))
	= "-[<var>:<label><!isEmpty(props)?" { <intercalate(", ", [neopp(p) | p <- props])> }":"">]-\><neopp(nodePattern)>";
	
str neopp(nodePattern(str var, list[str] labels, list[Property] props))
	= "(<var> <isEmpty(labels)?"":":" + intercalate(":", labels)><!isEmpty(props)?" { <intercalate(", ", [neopp(p) | p <- props])> }":"">)";
	
str neopp(property(str name, NeoExpr expr))
	="<q(name)> : <neopp(expr)>";

str neopp(match(list[NeoExpr] es, list[As] as, list[Clause] cs))
  = "match (<intercalate(", ", [ neopp(a) | As a <- as ])>)
    '<intercalate("\n", [ neopp(c) | Clause c <- cs ])>
    'return <intercalate(", ", [ neopp(e) | NeoExpr e <- es ])>"
    ;  

str neopp(create(str t, list[Column] cs, list[TableConstraint] cos))
  = "create table <q(t)> (
    '  <intercalate(",\n", [ neopp(c) | Column c <- cs ] + [ neopp(c) | TableConstraint c <- cos ])>
    ');";

str neopp(rename(str t, str newName))
  = "rename table <q(t)> to <q(newName)>;";

str neopp(create(str t, list[str] ps, list[NeoExpr] vs))
  = "create (n:<q(t)> { <intercalate(", ", [ "<q(ps[i])> : <neopp(vs[i])>" | i <- [0..size(ps)]])> })";
  
// Set

str neopp(\set(str c, NeoExpr e)) = "<q(c)> = <neopp(e)>";


// NeoExpr

str neopp(property(str \node, str name)) = "<\node>.<q(name)>";
str neopp(named(NeoExpr e, str as)) = "<neopp(e)> as <q(as)>";
str neopp(lit(NeoValue val)) = neopp(val);
str neopp(mapLit(map[str, NeoExpr] exprs)) = "{ <intercalate(", ", ["<k> : <neopp(exprs[k])>"| k <- exprs])> }";
str neopp(placeholder(name = str name)) =  name == "" ? "?" : "${<name>}";
str neopp(not(NeoExpr arg)) = "not (<neopp(arg)>)";
str neopp(neg(NeoExpr arg)) = "-(<neopp(arg)>)"; 
str neopp(pos(NeoExpr arg)) = "+(<neopp(arg)>)";
str neopp(mul(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) * (<neopp(rhs)>)"; 
str neopp(div(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) / (<neopp(rhs)>)"; 
str neopp(add(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) + (<neopp(rhs)>)"; 
str neopp(sub(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) - (<neopp(rhs)>)"; 
str neopp(equ(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) = (<neopp(rhs)>)"; 
str neopp(neq(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) \<\> (<neopp(rhs)>)"; 
str neopp(leq(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) \<= (<neopp(rhs)>)"; 
str neopp(geq(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) \>= (<neopp(rhs)>)"; 
str neopp(lt(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) \< (<neopp(rhs)>)"; 
str neopp(gt(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) \> (<neopp(rhs)>)"; 
str neopp(like(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) like (<neopp(rhs)>)"; 
str neopp(or(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) or (<neopp(rhs)>)"; 
str neopp(and(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) and (<neopp(rhs)>)";
str neopp(notIn(NeoExpr arg, list[NeoValue] vals)) 
  = "(<neopp(arg)>) not in (<intercalate(", ", [ neopp(v) | NeoValue v <- vals])>)";
str neopp(\in(NeoExpr arg, list[NeoValue] vals)) 
  = "(<neopp(arg)>) in (<intercalate(", ", [ neopp(v) | NeoValue v <- vals])>)";

str neopp(fun(str name, vals)) = "<name>(<intercalate(", ", [neopp(v) | v <- vals])>)";

str neopp(NeoExpr::placeholder(name = str name)) = "${<name>}";

// Clause

str neopp(where(list[NeoExpr] es)) = "where <intercalate(" and ", [ neopp(e) | NeoExpr e <- es ])>"; 

str neopp(groupBy(list[NeoExpr] es)) = "group by <intercalate(", ", [ neopp(e) | NeoExpr e <- es ])>"; 

str neopp(having(list[NeoExpr] es)) = "having <intercalate(", ", [ neopp(e) | NeoExpr e <- es ])>"; 

str neopp(orderBy(list[NeoExpr] es, Dir d)) = "order by <intercalate(", ", [ neopp(e) | NeoExpr e <- es ])> <neopp(d)>"; 

str neopp(limit(NeoExpr e)) = "limit <neopp(e)>"; 

// Dir

str neopp(asc()) = "asc";

str neopp(desc()) = "desc";

// Value

str neopp(text(str x)) = "\'<escape(x, ("\'": "\'\'"))>\'";

str neopp(decimal(real x)) = "<x>";

str neopp(integer(int x)) = "<x>";

str neopp(boolean(bool b)) = "<b>";

str neopp(dateTime(datetime d)) = "\'<printDate(d, "YYYY-MM-dd HH:mm:ss")>\'";

str neopp(date(datetime d)) = "\'<printDate(d, "YYYY-MM-dd")>\'";

str neopp(point(real x, real y)) = "PointFromText(\'POINT(<x> <y>)\', 4326)";

str neopp(polygon(list[lrel[real, real]] segs)) 
  = "PolyFromText(\'POLYGON(<intercalate(", ", [ seg2str(s) | s <- segs ])>)\', 4326)";

str seg2str(lrel[real,real] seg)  
  = "(<intercalate(", ", [ "<x> <y>" | <real x, real y> <- seg ])>)";

str neopp(null()) = "null";

str neopp(NeoValue::placeholder(name = str name)) = "${<name>}";

// TableConstraint

str neopp(primaryKey(str c)) = "primary key (<q(c)>)";

str neopp(foreignKey(str c, str p, str k, OnDelete od)) 
  = "foreign key (<q(c)>) 
    '  references <q(p)>(<q(k)>)<neopp(od)>";


str neopp(index(_, spatial(), list[str] columns))
    = intercalate(", ", ["spatial index(<q(c)>)" | c <- columns]);

// ColumnConstraint

str neopp(notNull()) = "not null";

str neopp(unique()) = "unique";


// ColumnType

str neopp(char(int size)) = "char(<size>)";
str neopp(varchar(int size)) = "varchar(<size>)";
str neopp(text()) = "text";
str neopp(integer()) = "integer";
str neopp(float()) = "float";
str neopp(double()) = "double";
str neopp(blob()) = "blob";
str neopp(date()) = "date";
str neopp(dateTime()) = "datetime";
str neopp(point()) = "point";
str neopp(polygon()) = "polygon";

