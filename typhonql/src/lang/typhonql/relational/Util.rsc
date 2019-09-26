module lang::typhonql::relational::Util

import lang::typhonql::relational::SQL;
import List;

str tableName(str entity) = "<entity>";

str columnName(str attr, str entity) = "<entity>.<attr>";

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

ColumnType typhonType2SQL("Date") = dateTime();

ColumnType typhonType2SQL("String") = text();

ColumnType typhonType2SQL("Real") = float();

ColumnType typhonType2SQL("int") = integer();

ColumnType typhonType2SQL("Int") = integer();


default ColumnType typhonType2SQL(str t) { throw "Unsupported Typhon type <t>"; }
