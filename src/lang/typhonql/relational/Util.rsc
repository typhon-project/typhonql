module lang::typhonql::relational::Util

import lang::typhonql::relational::SQL;
import List;

str tableName(str entity) = "<entity>_entity";


// we sort here to canonicalize the junction table name
// and be independent of wether we navigate from either 
// side of a bidirectional reference
str junctionTableName(str from, str fromRole, str to, str toRole)
  = ( "" | it + x | str x <- sort([from, fromRole, toRole, to]) ) + "_reference";

str junctionFkName(str from, str role)
  = "<from>_<role>";

str fkName(str toRole, str fromRole) = toRole == "" ? fkName(fromRole) : fkName(toRole);

str fkName(str field) = "<field>_id";

Column typhonIdColumn(str entity) = column(typhonId(entity), typhonIdType(), [notNull(), unique()]);

str typhonId(str entity) = "_typhon_id"; // entity to disambiguate if needed

ColumnType typhonIdType() = char(36); // UUID

ColumnType typhonType2SQL("Date") = date();

ColumnType typhonType2SQL("String") = text();

ColumnType typhonType2SQL("int") = integer();

default ColumnType typhonType2SQL(str t) { throw "Unsupported Typhon type <t>"; }
