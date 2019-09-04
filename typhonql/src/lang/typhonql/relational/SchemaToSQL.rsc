module lang::typhonql::relational::SchemaToSQL

import lang::typhonql::relational::SQL;
import lang::typhonql::relational::Util;
import lang::typhonql::relational::SQL2Text;
import lang::typhonml::Util; // Schema
import lang::typhonml::TyphonML;
import IO;
import Set;
import List;

/*
 * TODO
 * - make up mind about how much constraints in SQL
 * - figure out how to deal with containment/refs to outside entities
 */


//map[Place, list[SQLStat]] schema2sql(Schema schema) {
//  result = ();
//  for (Place p <- schema.placement<0>, p.db is sql) {
//    result[p] = schema2sql(schema, p, schema.placement[p]);
//  }
//  return result;
//}


void printSQLSchema(Schema schema, str dbName) {
  Place p = <sql(), dbName>;
  set[str] es = schema.placement[p];
  println(pp(schema2sql(schema, p, es, doForeignKeys = false)));
}


list[SQLStat] schema2sql(Schema schema, Place place, set[str] placedEntities, bool doForeignKeys = true) {
  schema.rels = symmetricReduction(schema.rels);
 
  SQLStat attrs2create(str e, rel[str, str] attrs) {
    return create(tableName(e), [typhonIdColumn(e)]
      + [column(columnName(attr, e), typhonType2SQL(typ), []) | <str attr, str typ> <- attrs ]
      , [primaryKey(typhonId(e))]);
  }
 
  stats = [ dropTable([tableName(e)], true, []) | str e <- placedEntities ];
  stats += [ attrs2create(e, schema.attrs[e]) | str e <- placedEntities ];
  
  // ugh...
  int createOfEntity(str entity) {
    for (int i <- [0..size(stats)]) {
      if (stats[i] is create, stats[i].table == tableName(entity)) {
        return i;
      }
    }
    stats += [dropTable([tableName(entity)], true, []), 
              create(tableName(entity), [], [])];
    return size(stats) - 1;
    //assert false: "Could not find create statement for entity <entity>";
  }
  
  void illegal(Rel r) {
    throw "Illegal relation: <r>";
  }
  
  // NB: we add foreign key constraints with alter table to avoid cyclic reference issues.
  
  void addCascadingForeignKey(str from, str fromRole, str to, str toRole, list[ColumnConstraint] cs) {
    kid = createOfEntity(to);
    fk = fkName(from, to, toRole == "" ? fromRole : toRole);
    stats[kid].cols += [ column(fk, typhonIdType(), cs) ]; 
    stats += [alterTable(tableName(to), [addConstraint(foreignKey(fk, tableName(from), typhonId(from), cascade()))]) | doForeignKeys ]; 
  }
  
  // should we make both fk's the combined primary key, if so, when?
  void addJunctionTable(str from, str fromRole, str to, str toRole) {
    str left = junctionFkName(from, fromRole);
    str right = junctionFkName(to, toRole);
    str tbl = junctionTableName(from, fromRole, to, toRole);
    SQLStat stat = create(tbl, [
      column(left, typhonIdType(), [notNull()]),
      column(right, typhonIdType(), [notNull()])      
    ], [
      foreignKey(left, tableName(from), typhonId(from), cascade()),
      foreignKey(right, tableName(to), typhonId(to), cascade()) 
        | doForeignKeys ]);
    stats += [dropTable([tbl], true, []), stat];
  }
  
  for (r:<str from, Cardinality fromCard, str fromRole, str toRole, Cardinality toCard, str to, bool contain> <- schema.rels
        // first do all the local ones
         , from in placedEntities, to in placedEntities) { 
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
       
       // we realize all cross refs using a junction table.
       case <_, _, false>: addJunctionTable(from, fromRole, to, toRole);
       
     }
  } 
  
  void addJunctionTableOutside(str from, str fromRole, str to, str toRole) {
    str left = junctionFkName(from, fromRole);
    str right = junctionFkName(to, toRole);
    str tbl = junctionTableName(from, fromRole, to, toRole);
    SQLStat stat = create(tbl, [
      column(left, typhonIdType(), [notNull()]),
      column(right, typhonIdType(), [notNull()])      
    ], [
      foreignKey(left, tableName(from), typhonId(from), cascade()) | doForeignKeys
    ]);
    stats += [dropTable([tbl], true, []), stat];
  }
  
  for (r:<str from, Cardinality fromCard, str fromRole, str toRole, Cardinality toCard, str to, bool contain> <- schema.rels
        // then relations to outside
         , from in placedEntities, to notin placedEntities) {
     addJunctionTableOutside(from, fromRole, to, toRole); 
  } 
  
  return  stats;  
}



