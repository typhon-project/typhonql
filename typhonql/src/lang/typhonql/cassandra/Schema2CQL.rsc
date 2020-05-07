module lang::typhonql::cassandra::Schema2CQL

import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::cassandra::CQL;

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
     [ cColumnDef(typhonId(e), cUUID(), primaryKey=true) ];;
  
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

CQLType type2cql("datetime") = cTime();

CQLType type2cql(/^string.<n:[0-9]+>./) = cText();

CQLType type2cql(/^freetext/) = cText();

CQLType type2cql("blob") = cBlob();

CQLType type2cql("text") = cText();

CQLType type2cql("float") = cFloat();

CQLType type2cql("int") = cInteger();

CQLType type2cql("bigint") = cBigint();

CQLType type2cql("point") = { throw "Not yet supported: define UDT for point"; };

CQLType type2cql("polygon") = { throw "Not yet supported: define UDT for polygon"; };

default CQLType type2cql(str t) { throw "Unsupported Typhon type <t>"; }


