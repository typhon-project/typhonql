/********************************************************************************
* Copyright (c) 2018-2020 CWI & Swat.engineering 
*
* This program and the accompanying materials are made available under the
* terms of the Eclipse Public License 2.0 which is available at
* http://www.eclipse.org/legal/epl-2.0.
*
* This Source Code may also be made available under the following Secondary
* Licenses when the conditions for such availability set forth in the Eclipse
* Public License, v. 2.0 are satisfied: GNU General Public License, version 2
* with the GNU Classpath Exception which is
* available at https://www.gnu.org/software/classpath/license.html.
*
* SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0
********************************************************************************/

module lang::typhonql::relational::Util

import lang::typhonql::Expr;
import lang::typhonql::util::Strings;
import lang::typhonql::relational::SQL;
import List;
import String;
import IO;
import ValueIO;

SQLExpr pointer2sql(pointerUuid(str name)) = SQLExpr::lit(sUuid(name));
SQLExpr pointer2sql(pointerPlaceholder(str name)) = SQLExpr::placeholder(name = name);

str tableName(str entity) = "<entity>";

str columnName(str attr, str entity) = "<entity>.<attr>";

str columnName(str attr, str entity, str custom, str element) = "<entity>.<attr>.<custom>.<element>";

str typhonId(str entity) = columnName("@id", entity); 

// we sort here to canonicalize the junction table name
// and be independent of wether we navigate from either 
// side of a bidirectional reference
str junctionTableName(str from, str fromRole, str to, str toRole) {
  lst = sort([from, to]);
  if (lst == [from, to]) {
    return "<from>.<roleName(fromRole)>-<to>.<roleName(toRole)>";
  }
  return  "<to>.<roleName(toRole)>-<from>.<roleName(fromRole)>";
}

str roleName(str role) = role == "" ? "unknown" : role;

str junctionFkName(str from, str role)
  = "<from>.<roleName(role)>";

// todo: since we can only be contained by one thing, we can just do parent.@id as foreign keys.
// but not with junctions because they can be between the same thing
str fkName(str from, str to, str role) = columnName(role, "<from>.<to>");

//str fkName(str field) = "<field>_id";

Column typhonIdColumn(str entity) = column(typhonId(entity), typhonIdType(), [notNull(), unique()]);


ColumnType typhonIdType() = uuidType();

ColumnType typhonType2SQL("date") = date();

ColumnType typhonType2SQL("datetime") = dateTime();

ColumnType typhonType2SQL(/^string.<n:[0-9]+>./) = varchar(toInt(n));

ColumnType typhonType2SQL(/^freetext/) = text();

ColumnType typhonType2SQL("blob") = blob();

ColumnType typhonType2SQL("text") = text();

ColumnType typhonType2SQL("float") = float();

ColumnType typhonType2SQL("int") = integer();

ColumnType typhonType2SQL("bigint") = bigint();

ColumnType typhonType2SQL("point") = point();

ColumnType typhonType2SQL("polygon") = polygon();

// legacy (for temporary backwards compatibility)

ColumnType typhonType2SQL("Real") = float();

ColumnType typhonType2SQL("String") = text();
ColumnType typhonType2SQL("bool") = boolean();

ColumnType typhonType2SQL("string") = text();

ColumnType typhonType2SQL("Date") = date();

ColumnType typhonType2SQL("Blob") = blob();

ColumnType typhonType2SQL("natural_language") = text();

default ColumnType typhonType2SQL(str t) { throw "Unsupported Typhon type <t>"; }

list[ColumnConstraint] typhonType2Constrains("point") = [notNull()];
list[ColumnConstraint] typhonType2Constrains("polygon") = [notNull()];
default list[ColumnConstraint] typhonType2Constrains(str t) = [];

list[str] columnName((KeyVal)`<Id x>: <EId customType> (<{KeyVal ","}* keyVals>)`, str entity) = [columnName("<x>", entity, "<customType>", "<y>") | (KeyVal)`<Id y>: <Expr e>` <- keyVals];

list[str] columnName((KeyVal)`<Id x>: <Expr e>`, str entity) = [columnName("<x>", entity)]
	when (Expr) `<Custom c>` !:= e;

list[str] columnName((KeyVal)`@id: <Expr _>`, str entity) = [typhonId(entity)]; 

list[SQLExpr] evalKeyVal((KeyVal) `<Id x>: <EId customType> (<{KeyVal ","}* keyVals>)`) 
  = [lit(evalExpr(e)) | (KeyVal)`<Id x>: <Expr e>` <- keyVals];

list[SQLExpr] evalKeyVal((KeyVal)`<Id _>: <Expr e>`) = [lang::typhonql::relational::SQL::lit(evalExpr(e))]
	when (Expr) `<Custom c>` !:= e;

list[SQLExpr] evalKeyVal((KeyVal)`@id: <Expr e>`) = [lit(evalExpr(e))];

Value evalExpr((Expr)`<VId v>`) { throw "Variable still in expression"; }
 
// todo: unescaping (e.g. \" to ")!
Value evalExpr((Expr)`<Str s>`) = Value::text(unescapeQLString(s));

Value evalExpr((Expr)`<Int n>`) = Value::integer(toInt("<n>"));

Value evalExpr((Expr)`<Bool b>`) = Value::boolean("<b>" == "true");

Value evalExpr((Expr)`<Real r>`) = Value::decimal(toReal("<r>"));

Value evalExpr((Expr)`#point(<Real x> <Real y>)`) = Value::point(toReal("<x>"), toReal("<y>"));

Value evalExpr((Expr)`#polygon(<{Segment ","}* segs>)`)
  = Value::polygon([ seg2lrel(s) | Segment s <- segs ]);
  
lrel[real, real] seg2lrel((Segment)`(<{XY ","}* xys>)`)
  = [ <toReal("<x>"), toReal("<y>")> | (XY)`<Real x> <Real y>` <- xys ]; 

Value evalExpr((Expr)`<DateAndTime d>`) =Value::dateTime(readTextValueString(#datetime, "<d>"));

Value evalExpr((Expr)`<JustDate d>`) = Value::date(readTextValueString(#datetime, "<d>"));

// should only happen for @id field (because refs should be done via keys etc.)
Value evalExpr((Expr)`<UUID u>`) = sUuid("<u.part>");

Value evalExpr((Expr)`#blob:<UUIDPart prt>`) = blobPointer("<prt>");

Value evalExpr((Expr)`<PlaceHolder p>`) = Value::placeholder(name="<p>"[2..]);

default Value evalExpr(Expr ex) { throw "missing case for <ex>"; }