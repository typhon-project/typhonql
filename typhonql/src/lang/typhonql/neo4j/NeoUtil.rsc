module lang::typhonql::neo4j::NeoUtil

import lang::typhonql::TDBC;
import lang::typhonql::neo4j::Neo;
import lang::typhonml::Util;
import lang::typhonql::util::Strings;

import String;
import ValueIO;

str neoTyphonId(str entity) = graphPropertyName("@id", entity);
str nodeName(str entity) = "<entity>";
str graphPropertyName(str attr, str entity) = "<entity>.<attr>";

NeoExpr pointer2neo(pointerUuid(str name)) = nLit(nText(name));
NeoExpr pointer2neo(pointerPlaceholder(str name)) = NeoExpr::nPlaceholder(name = name);

list[str] propertyName((KeyVal)`<Id x>: <EId customType> (<{KeyVal ","}* keyVals>)`, str entity) = [graphPropertyName("<x>", entity, "<customType>", "<y>") | (KeyVal)`<Id y>: <Expr e>` <- keyVals];

list[str] propertyName((KeyVal)`<Id x>: <Expr e>`, str entity) = [graphPropertyName("<x>", entity)]
	when (Expr) `<Custom c>` !:= e;

list[str] propertyName((KeyVal)`@id: <Expr _>`, str entity) = [typhonId(entity)]; 

list[NeoExpr] evalKeyVal((KeyVal) `<Id x>: <EId customType> (<{KeyVal ","}* keyVals>)`) 
  = [lit(evalNeoExpr(e)) | (KeyVal)`<Id x>: <Expr e>` <- keyVals];

list[NeoExpr] evalKeyVal((KeyVal)`<Id _>: <Expr e>`) = [nLit(evalNeoExpr(e))]
	when (Expr) `<Custom c>` !:= e;

list[NeoExpr] evalKeyVal((KeyVal)`@id: <Expr e>`) = [nLit(evalNeoExpr(e))];

NeoValue evalNeoExpr((Expr)`<VId v>`) { throw "Variable still in expression"; }
 
// todo: unescaping (e.g. \" to ")!
NeoValue evalNeoExpr((Expr)`<Str s>`) = nText(unescapeQLString(s));

NeoValue evalNeoExpr((Expr)`<Int n>`) = nInteger(toInt("<n>"));
//NeoValue evalNeoExpr((Expr)`-<Int n>`) = nInteger(toInt("-<n>"));

NeoValue evalNeoExpr((Expr)`<Bool b>`) = nBoolean("<b>" == "true");

NeoValue evalNeoExpr((Expr)`<Real r>`) = nDecimal(toReal("<r>"));
//NeoValue evalNeoExpr((Expr)`-<Real r>`) = nDecimal(toReal("-<r>"));

NeoValue evalNeoExpr((Expr)`#point(<Real x> <Real y>)`) = nPoint(toReal("<x>"), toReal("<y>"));

NeoValue evalNeoExpr((Expr)`#polygon(<{Segment ","}* segs>)`)
  = nPolygon([ seg2lrel(s) | Segment s <- segs ]);
  
lrel[real, real] seg2lrel((Segment)`(<{XY ","}* xys>)`)
  = [ <toReal("<x>"), toReal("<y>")> | (XY)`<Real x> <Real y>` <- xys ]; 

NeoValue evalNeoExpr((Expr)`<DateAndTime d>`) = nDateTime(readTextValueString(#datetime, "<d>"));

NeoValue evalNeoExpr((Expr)`<JustDate d>`) = nDate(readTextValueString(#datetime, "<d>"));

// should only happen for @id field (because refs should be done via keys etc.)
NeoValue evalNeoExpr((Expr)`<UUID u>`) = nText("<u>"[1..]);

NeoValue evalNeoExpr((Expr)`<PlaceHolder p>`) = nPlaceholder(name="<p>"[2..]);

default NeoValue evalNeoExpr(Expr ex) { throw "missing case for <ex>"; }

bool isAttr((KeyVal)`<Id x>: <Expr _>`, str e, Schema s) = <e, "<x>", _> <- s.attrs;

bool isAttr((KeyVal)`<Id x> +: <Expr _>`, str e, Schema s) = false;

bool isAttr((KeyVal)`<Id x> -: <Expr _>`, str e, Schema s) = false;

bool isAttr((KeyVal)`@id: <Expr _>`, str _, Schema _) = false;
