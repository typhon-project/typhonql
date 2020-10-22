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

module lang::typhonql::cassandra::Schema2CQL

import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::cassandra::CQL;
import lang::typhonql::cassandra::CQL2Text;

import IO;

str cTableName(str entity) = entity;
str cColName(str entity, str x) = x;
str cTyphonId(str entity) = "@id";

list[CQLStat] schema2cql(Schema s, Place p, set[str] entities) {
  list[CQLStat] stmts = [];
  
  // TODO: maybe use "\"<p.name>\".<cTableName(e)>" here.
  stmts += [ cDropTable(cTableName(e), ifExists=true) | str e <- entities ];
  
  stmts += [ cCreateTable(cTableName(e), entityCols(e, s)) | str e <- entities ]; 
  
  return stmts;
} 

list[CQLColumnDefinition] entityCols(str ent, Schema s) {
  list[CQLColumnDefinition] cols = 
     [ cColumnDef(cTyphonId(ent), cUUID(), primaryKey=true) ];;
  
  cols += [ cColumnDef(cColName(ent, name), type2cql(typ)) 
    | <ent, str name, str typ> <- s.attrs ]; 

  cols += [ cColumnDef(cColName(ent, fromRole), cUUID()) 
    | <ent, Cardinality fromCard, str fromRole, _, _, _, _> <- s.rels
    , fromCard in {\one(), zero_one()} ];
    
  cols += [ cColumnDef(cColName(ent, fromRole), cSet(cUUID())) 
    | <ent, Cardinality fromCard, str fromRole, _, _, _, _> <- s.rels
    , fromCard in {zero_many(), one_many()} ];
    
  return cols;
}


CQLType type2cql("date") = cDate();

CQLType type2cql("datetime") = cTimestamp();

CQLType type2cql(/^string.<n:[0-9]+>./) = cText();

CQLType type2cql(/^freetext/) = cText();

CQLType type2cql("blob") = cBlob();

CQLType type2cql("text") = cText();

CQLType type2cql("float") = cFloat();

CQLType type2cql("int") = cInt();

CQLType type2cql("bigint") = cBigint();

CQLType type2cql("point") = { throw "Not yet supported: define UDT for point"; };

CQLType type2cql("polygon") = { throw "Not yet supported: define UDT for polygon"; };

default CQLType type2cql(str t) { throw "Unsupported Typhon type <t>"; }


void smokeIt() {
  s = schema({
    {"Person", "Review", "Comment", "Cash", "Reply" },
    <"Person", zero_many(), "reviews", "user", \one(), "Review", true>,
    <"Person", zero_many(), "cash", "owner", \one(), "Cash", true>,
    <"Review", \one(), "user", "reviews", \zero_many(), "Person", false>,
    <"Review", \one(), "comment", "owner", \zero_many(), "Comment", true>,
    <"Comment", zero_many(), "replies", "owner", \zero_many(), "Comment", true>
  }, {
    <"Person", "name", "text">,
    <"Person", "age", "int">,
    <"Cash", "amount", "int">,
    <"Review", "text", "text">,
    <"Comment", "contents", "text">,
    <"Reply", "reply", "text">
  },
  placement = {
    <<cassandra(), "Inventory">, "Person">,
    <<cassandra(), "Inventory">, "Cash">,
    <<cassandra(), "Inventory">, "Review">,
    <<cassandra(), "Inventory">, "Comment">
  }
  );
  
  Place p = <cassandra(), "Inventory">;
  for (CQLStat stmt <- schema2cql(s, p, s.placement[p])) {
    println(pp(stmt));
  }
}
