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

str neopp(nMatchUpdate(just(nMatch(list[NeoPattern] ps, list[NeoClause] cs)), NeoUpdateClause uc, list[NeoExpr] es))
  = "match <intercalate(", ", [ neopp(p) | NeoPattern p <- ps ])>
    '<intercalate("\n", [ neopp(c) | NeoClause c <- cs ])>
    '<neopp(uc)>
    '<isEmpty(es)?"":"return "><intercalate(", ", [ neopp(e) | NeoExpr e <- es ])>"
    ;  

str neopp(nMatchUpdate(nothing(), NeoUpdateClause uc, list[NeoExpr] es))
  = "<neopp(uc)>
    '<isEmpty(es)?"":"return "><intercalate(", ", [ neopp(e) | NeoExpr e <- es ])>";  
    
str neopp(nMatchQuery(list[NeoMatch] matches, list[NeoExpr] es))
  = "<intercalate("\n", [neopp(m) | m <- matches])>
    'return <intercalate(", ", [ neopp(e) | NeoExpr e <- es ])>"
    ;  
    
str neopp(nMatch(list[NeoPattern] ps, list[NeoClause] cs)) 
   ="match <intercalate(", ", [ neopp(p) | NeoPattern p <- ps ])>
    '<intercalate("\n", [ neopp(c) | NeoClause c <- cs ])>";
    
str neopp(nCallYield(str name, list[NeoExpr] args, list[str] procedureResults))
   ="call <name>(<intercalate(", ", [ neopp(e) | NeoExpr e <- args ])>)
    'yield <intercalate(", ", [ p | str p <- procedureResults ])>";
        
str neopp(nCreate(NeoPattern pattern))
  = "create <neopp(pattern)>";
  
str neopp(nDetachDelete(list[NeoExpr] exprs))
  = "detach delete <intercalate(", ", [neopp(e) | e <- exprs])>";

str neopp(nDelete(list[NeoExpr] exprs))
  = "delete <intercalate(", ", [neopp(e) | e <- exprs])>";

str neopp(nSet(list[NeoSetItem] setItems))
  = "set <intercalate(", ", [neopp(i) | i <- setItems])>";
  
str neopp(nSetEquals(str variable, NeoExpr expr))
  = "<variable> = <neopp(expr)>";
  
str neopp(nSetPlusEquals(str variable, NeoExpr expr))
  = "<variable> += <neopp(expr)>";  
  
str neopp(nPattern(nodePattern, rels))
	= "<neopp(nodePattern)><intercalate(" ", [neopp(r) | r <- rels])>";
	
str neopp(nRelationshipPattern(NeoDirection dir, str var, str label, list[NeoProperty] props, NeoNodePattern nodePattern))
	= "-[<var>:<label><!isEmpty(props)?" { <intercalate(", ", [neopp(p) | p <- props])> }":"">]-\><neopp(nodePattern)>";
	
str neopp(nNodePattern(str var, list[str] labels, list[NeoProperty] props))
	= "(<var> <isEmpty(labels)?"":":" + intercalate(":", labels)><!isEmpty(props)?" { <intercalate(", ", [neopp(p) | p <- props])> }":"">)";
	
str neopp(nProperty(str name, NeoExpr expr))
	="<q(name)> : <neopp(expr)>";


str neopp(nCreate(str t, list[str] ps, list[NeoExpr] vs))
  = "create (n:<q(t)> { <intercalate(", ", [ "<q(ps[i])> : <neopp(vs[i])>" | i <- [0..size(ps)]])> })";
  
// Set

str neopp(nSet(str c, NeoExpr e)) = "<q(c)> = <neopp(e)>";


// NeoExpr

str neopp(nProperty(str \node, str name)) = "<\node>.<q(name)>";
str neopp(nNamed(NeoExpr e, str as)) = "<neopp(e)> as <q(as)>";
str neopp(nVariable(name)) = name;
str neopp(nLit(NeoValue val)) = neopp(val);
str neopp(nMapLit(map[str, NeoExpr] exprs)) = "{ <intercalate(", ", ["<q(k)> : <neopp(exprs[k])>"| k <- exprs])> }";
str neopp(nPlaceholder(name = str name)) =  name == "" ? "?" : "$<name>";
str neopp(nNot(NeoExpr arg)) = "not (<neopp(arg)>)";
str neopp(nNeg(NeoExpr arg)) = "-(<neopp(arg)>)"; 
str neopp(nPos(NeoExpr arg)) = "+(<neopp(arg)>)";
str neopp(nMul(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) * (<neopp(rhs)>)"; 
str neopp(nDiv(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) / (<neopp(rhs)>)"; 
str neopp(nAdd(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) + (<neopp(rhs)>)"; 
str neopp(nSub(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) - (<neopp(rhs)>)"; 
str neopp(nEqu(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) = (<neopp(rhs)>)"; 
str neopp(nNeq(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) \<\> (<neopp(rhs)>)"; 
str neopp(nLeq(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) \<= (<neopp(rhs)>)"; 
str neopp(nGeq(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) \>= (<neopp(rhs)>)"; 
str neopp(nLt(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) \< (<neopp(rhs)>)"; 
str neopp(nGt(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) \> (<neopp(rhs)>)"; 
str neopp(nLike(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) like (<neopp(rhs)>)"; 
str neopp(nOr(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) or (<neopp(rhs)>)"; 
str neopp(nAnd(NeoExpr lhs, NeoExpr rhs)) = "(<neopp(lhs)>) and (<neopp(rhs)>)";
str neopp(nNotIn(NeoExpr arg, list[NeoValue] vals)) 
  = "(<neopp(arg)>) not in (<intercalate(", ", [ neopp(v) | NeoValue v <- vals])>)";
str neopp(nIn(NeoExpr arg, list[NeoValue] vals)) 
  = "(<neopp(arg)>) in (<intercalate(", ", [ neopp(v) | NeoValue v <- vals])>)";
    
str neopp(nReaching(str edge, Maybe::just(lower), Maybe::nothing(), str lhs, str rhs))
 = "(<lhs>)-[:<edge>*<neopp(lower)>..]-\> (<rhs>)";

str neopp(nReaching(str edge, Maybe::nothing(), Maybe::just(upper), str lhs, str rhs))
 = "(<lhs>)-[:<edge>*..<neopp(upper)>]-\> (<rhs>)";

str neopp(nReaching(str edge, Maybe::just(lower), Maybe::just(upper), str lhs, str rhs))
 = "(<lhs>)-[:<edge>*<neopp(lower)>..<neopp(upper)>]-\> (<rhs>)";

str neopp(nReaching(str edge, Maybe::nothing(), Maybe::nothing(), str lhs, str rhs))
 = "(<lhs>)-[:<edge>*]-\> (<rhs>)";


str neopp(nFun(str name, vals)) = "<name>(<intercalate(", ", [neopp(v) | v <- vals])>)";

str neopp(nPlaceholder(name = str name)) = "$<name>";

// Clause

str neopp(nWhere(list[NeoExpr] es)) = "where <intercalate(" and ", [ neopp(e) | NeoExpr e <- es ])>"; 

str neopp(nGroupBy(list[NeoExpr] es)) = "group by <intercalate(", ", [ neopp(e) | NeoExpr e <- es ])>"; 

str neopp(nHaving(list[NeoExpr] es)) = "having <intercalate(", ", [ neopp(e) | NeoExpr e <- es ])>"; 

str neopp(nOrderBy(list[NeoExpr] es, Dir d)) = "order by <intercalate(", ", [ neopp(e) | NeoExpr e <- es ])> <neopp(d)>"; 

str neopp(nLimit(NeoExpr e)) = "limit <neopp(e)>"; 

// Dir

str neopp(nAsc()) = "asc";

str neopp(nDesc()) = "desc";

// Value

str neopp(nText(str x)) = "\'<escape(x, ("\'": "\'\'"))>\'";

str neopp(nDecimal(real x)) = "<x>";

str neopp(nInteger(int x)) = "<x>";

str neopp(nBoolean(bool b)) = "<b>";

str neopp(nDateTime(datetime d)) = "\'<printDate(d, "YYYY-MM-dd HH:mm:ss")>\'";

str neopp(nDate(datetime d)) = "\'<printDate(d, "YYYY-MM-dd")>\'";

str neopp(nPoint(real x, real y)) = "PointFromText(\'POINT(<x> <y>)\', 4326)";

str neopp(nPolygon(list[lrel[real, real]] segs)) 
  = "PolyFromText(\'POLYGON(<intercalate(", ", [ seg2str(s) | s <- segs ])>)\', 4326)";

str seg2str(lrel[real,real] seg)  
  = "(<intercalate(", ", [ "<x> <y>" | <real x, real y> <- seg ])>)";

str neopp(nNull()) = "null";

str neopp(nPlaceholder(name = str name)) = "$<name>";

// ColumnType

str neopp(nChar(int size)) = "char(<size>)";
str neopp(nVarchar(int size)) = "varchar(<size>)";
str neopp(nText()) = "text";
str neopp(nInteger()) = "integer";
str neopp(nFloat()) = "float";
str neopp(nDouble()) = "double";
str neopp(nBlob()) = "blob";
str neopp(nDate()) = "date";
str neopp(nDateTime()) = "datetime";
str neopp(nPoint()) = "point";
str neopp(nPolygon()) = "polygon";

