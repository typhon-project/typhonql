module lang::typhonql::relational::Util

import lang::typhonql::relational::SQL;

str tableName(str entity) = "<entity>_entity";


str junctionTableName(str from, str fromRole, str to, str toRole)
  = "<from>_<fromRole>_<toRole>_<to>";


str fkName(str field) = "<field>_id";

Column typhonIdColumn(str entity) = column(typhonId(entity), typhonIdType(), [notNull(), unique()]);

str typhonId(str entity) = "_typhon_id"; // entity to disambiguate if needed

ColumnType typhonIdType() = char(36); // UUID

ColumnType typhonType2SQL("Date") = date();

ColumnType typhonType2SQL("String") = text();

ColumnType typhonType2SQL("int") = integer();

default ColumnType typhonType2SQL(str t) { throw "Unsupported Typhon type <t>"; }
