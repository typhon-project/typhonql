module lang::typhonql::neo4j::NeoUtil

import lang::typhonql::Expr;
import lang::typhonql::neo4j::Neo;
import lang::typhonml::Util;

import String;

str typhonId(str entity) = propertyName("@id", entity);
str nodeName(str entity) = "<entity>";
str propertyName(str attr, str entity) = "<entity>.<attr>";


list[str] propertyName((KeyVal)`<Id x>: <EId customType> (<{KeyVal ","}* keyVals>)`, str entity) = [propertyName("<x>", entity, "<customType>", "<y>") | (KeyVal)`<Id y>: <Expr e>` <- keyVals];

list[str] propertyName((KeyVal)`<Id x>: <Expr e>`, str entity) = [propertyName("<x>", entity)]
	when (Expr) `<Custom c>` !:= e;

list[str] propertyName((KeyVal)`@id: <Expr _>`, str entity) = [typhonId(entity)]; 

list[NeoExpr] evalKeyVal((KeyVal) `<Id x>: <EId customType> (<{KeyVal ","}* keyVals>)`) 
  = [lit(evalExpr(e)) | (KeyVal)`<Id x>: <Expr e>` <- keyVals];

list[NeoExpr] evalKeyVal((KeyVal)`<Id _>: <Expr e>`) = [lit(evalExpr(e))]
	when (Expr) `<Custom c>` !:= e;

list[NeoExpr] evalKeyVal((KeyVal)`@id: <Expr e>`) = [lit(evalExpr(e))];

Value evalExpr((Expr)`<VId v>`) { throw "Variable still in expression"; }
 
// todo: unescaping (e.g. \" to ")!
Value evalExpr((Expr)`<Str s>`) = text("<s>"[1..-1]);

Value evalExpr((Expr)`<Int n>`) = integer(toInt("<n>"));

Value evalExpr((Expr)`<Bool b>`) = boolean("<b>" == "true");

Value evalExpr((Expr)`<Real r>`) = decimal(toReal("<r>"));

Value evalExpr((Expr)`#point(<Real x> <Real y>)`) = point(toReal("<x>"), toReal("<y>"));

Value evalExpr((Expr)`#polygon(<{Segment ","}* segs>)`)
  = polygon([ seg2lrel(s) | Segment s <- segs ]);
  
lrel[real, real] seg2lrel((Segment)`(<{XY ","}* xys>)`)
  = [ <toReal("<x>"), toReal("<y>")> | (XY)`<Real x> <Real y>` <- xys ]; 

Value evalExpr((Expr)`<DateAndTime d>`) = dateTime(readTextValueString(#datetime, "<d>"));

Value evalExpr((Expr)`<JustDate d>`) = date(readTextValueString(#datetime, "<d>"));

// should only happen for @id field (because refs should be done via keys etc.)
Value evalExpr((Expr)`<UUID u>`) = text("<u>"[1..]);

Value evalExpr((Expr)`<PlaceHolder p>`) = placeholder(name="<p>"[2..]);

default Value evalExpr(Expr ex) { throw "missing case for <ex>"; }

bool isAttr((KeyVal)`<Id x>: <Expr _>`, str e, Schema s) = <e, "<x>", _> <- s.attrs;

bool isAttr((KeyVal)`<Id x> +: <Expr _>`, str e, Schema s) = false;

bool isAttr((KeyVal)`<Id x> -: <Expr _>`, str e, Schema s) = false;

bool isAttr((KeyVal)`@id: <Expr _>`, str _, Schema _) = false;
  

