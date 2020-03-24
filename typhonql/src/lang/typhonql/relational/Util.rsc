module lang::typhonql::relational::Util

import lang::typhonql::relational::SQL;
import List;

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


ColumnType typhonIdType() = char(36); // UUID

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

ColumnType typhonType2SQL("String") = text();

ColumnType typhonType2SQL("Date") = date();

ColumnType typhonType2SQL("Blob") = text();

ColumnType typhonType2SQL("natural_language") = text();




default ColumnType typhonType2SQL(str t) { throw "Unsupported Typhon type <t>"; }
