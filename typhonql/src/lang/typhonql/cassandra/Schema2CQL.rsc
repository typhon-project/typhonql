module lang::typhonql::cassandra::Schema2CQL

import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::cassandra::CQL;
import lang::typhonql::cassandra::CQL2Text;

import IO;

str tableName(str entity) = entity;
str colName(str entity, str x) = "<entity>.<x>";
str typhonId(str entity) = "<entity>.@id";

list[CQLStat] schema2cql(Schema s, Place p, set[str] entities) {
  list[CQLStat] stmts = [];
  
  stmts += [ cDropTable(tableName(e), ifExists=true) | str e <- entities ];
  
  stmts += [ cCreateTable(tableName(e), entityCols(e, s)) | str e <- entities ]; 
  
  return stmts;
} 

list[CQLColumnDefinition] entityCols(str ent, Schema s) {
  list[CQLColumnDefinition] cols = 
     [ cColumnDef(typhonId(ent), cUUID(), primaryKey=true) ];;
  
  cols += [ cColumnDef(colName(ent, name), type2cql(typ)) 
    | <ent, str name, str typ> <- s.attrs ]; 

  cols += [ cColumnDef(colName(ent, fromRole), cUUID()) 
    | <ent, Cardinality fromCard, str fromRole, _, _, _, _> <- s.rels
    , fromCard in {\one(), zero_one()} ];
    
  cols += [ cColumnDef(colName(ent, fromRole), cSet(cUUID())) 
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

