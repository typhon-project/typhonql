module lang::typhonql::relational::ToSQL

import lang::typhonml::Util; // Schema
import lang::typhonql::relational::SQL;
import lang::typhonml::TyphonML;
import IO;
import Set;
import List;


list[SQLStat] schema2sql(Schema schema) {
  // for now, assume everyhting is local, (need fix of TyphonML)
 
  schema.rels = symmetricReduction(schema.rels);
 
  SQLStat attrs2create(str e, rel[str, str] attrs) {
    return create(tableName(e), [typhonIdColumn(e)]
      + [column(attr, typhonType2SQL(typ), []) | <str attr, str typ> <- attrs ]
      , [primaryKey(typhonId(e))]);
  }
 
  stats = [ attrs2create(e, schema.attrs[e]) | str e <- entities(schema) ];
  
  // ugh...
  int createOfEntity(str entity) {
    for (int i <- [0..size(stats)]) {
      if (stats[i].table == tableName(entity)) {
        return i;
      }
    }
    assert false: "Could not find create statement for entity <entity>";
  }
  
  void illegal(Rel r) {
    throw "Illegal relation: <r>";
  }
  
  // NB: we add foreign key constraints with alter table to avoid cyclic reference issues.
  
  void addCascadingForeignKey(str from, str fromRole, str to, str toRole, list[ColumnConstraint] cs) {
    kid = createOfEntity(to);
    fk = toRole == "" ? fkName(fromRole) : fkName(toRole);
    stats[kid].cols += [ column(fk, typhonIdType(), cs) ]; 
    stats += [alterTable(tableName(to), [addConstraint(foreignKey(fk, tableName(from), typhonId(from), cascade()))])]; 
  }
  
  // should we make both fk's the combined primary key, if so, when?
  void addJunctionTable(str from, str fromRole, str to, str toRole) {
    str left = fkName("<from>_<fromRole>");
    str right = fkName("<to>_<toRole>");
    SQLStat stat = create(junctionTableName(from, fromRole, to, toRole), [
      column(left, typhonIdType(), [notNull()]),
      column(right, typhonIdType(), [notNull()])      
    ], [
      foreignKey(left, tableName(from), typhonId(from), cascade()),
      foreignKey(right, tableName(to), typhonId(to), cascade())
    ]);
    stats += [stat];
  }
  
  for (r:<str from, Cardinality fromCard, str fromRole, str toRole, Cardinality toCard, str to, bool contain> <- schema.rels) {
     switch (<fromCard, toCard, contain>) {
       case <one_many(), one_many(), true>: illegal(r);
       case <one_many(), zero_many(), true>: illegal(r);
       case <one_many(), zero_one(), true>: illegal(r);
       case <one_many(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, []); // ??? how to enforce one_many?
       
       
       case <zero_many(), one_many(), true>: illegal(r);
       case <zero_many(), zero_many(), true>: illegal(r);
       case <zero_many(), zero_one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, []);
       
       case <zero_many(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [notNull()]);

       case <zero_one(), one_many(), true>: illegal(r);
       case <zero_one(), zero_many(), true>: illegal(r);
       case <zero_one(), zero_one(), true>: illegal(r);
       case <zero_one(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [unique(), notNull()]);
       
       case <\one(), one_many(), true>: illegal(r);
       case <\one(), zero_many(), true>: illegal(r);
       case <\one(), zero_one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, []);
       case <\one(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [unique(), notNull()]);
       
       case <_, _, false>: addJunctionTable(from, fromRole, to, toRole);
       
//       case <one_many(), one_many(), false>: ;
//       case <one_many(), zero_many(), false>: ;
//       case <one_many(), zero_one(), false>: ;
//       case <one_many(), \one(), false>: ;
//       
//       
//       case <zero_many(), one_many(), false>: ;
//       case <zero_many(), zero_many(), false>: ;
//       case <zero_many(), zero_one(), false>: ;
//       case <zero_many(), \one(), false>: ;
//
//       case <zero_one(), one_many(), false>: ;
//       case <zero_one(), zero_many(), false>: ;
//       case <zero_one(), zero_one(), false>: ;
//       case <zero_one(), \one(), false>: ;
//       
//       case <\one(), one_many(), false>: ; //unique left
//       case <\one(), zero_many(), false>: ; //unique left
//       case <\one(), zero_one(), false>: ; // unique left, 
//       case <\one(), \one(), false>: ; // unique left, unique right
       
     }
  } 
  
  return  stats;  
}


set[str] entities(Schema s) = s.rels<0> + s.attrs<0>;

str tableName(str entity) = "<entity>_entity";

str typhonId(str entity) = "_typhon_id"; // entity to disambiguate if needed

str junctionTableName(str from, str fromRole, str to, str toRole)
  = "<from>_<fromRole>_<toRole>_<to>";


str fkName(str field) = "<field>_id";

Column typhonIdColumn(str entity) = column(typhonId(entity), typhonIdType(), [notNull(), unique()]);

ColumnType typhonIdType() = char(36); // UUID

ColumnType typhonType2SQL("Date") = date();
ColumnType typhonType2SQL("String") = text();
ColumnType typhonType2SQL("int") = integer();
default ColumnType typhonType2SQL(str t) { throw "Unsupported Typhon type <t>"; }


/*

create table `<Entity>` (
  `typhon_id` char(36) not null, 
  
  
  primary key (`typhon_id`), 
  
);

Foreign keys

create table `...` (

<owner>_id char(36),
    FOREIGN KEY (<owner>_id)
        REFERENCES owner(typhon_id)
        ON DELETE CASCADE
)

*/

/*

rel[str, Cardinality, name, name, Cardinality, str]

# Mapping

## Types

Date
String
int
Blob

## Relations

:-> [1]     put foreign in target table, add cascade delete
            or put foreign key in parent, add cascade delete, and foreign key in child and cascade delete (???)
:-> [0..1]     (and assume parent is always 1; no containment from multiple things)
:-> [0..*]

-> [1]      always use junction table, unless inverse of containment
-> [0..1]
-> [0..*]

If they are outside the database, what then? (assume for now, never containment)
 - if it's one, put column with uuid non null (if optional, can be null)



*/