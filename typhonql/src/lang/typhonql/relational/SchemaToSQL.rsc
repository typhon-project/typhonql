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

data Stats = stats(void(SQLStat) add, void(int, SQLStat) addAt, list[SQLStat]() get);

Stats initializeStats() {
	list[SQLStat] lst = [];
	
	void addStat(SQLStat s) { lst += s; }
	
	list[SQLStat] getStat() { return lst; }
	
	void addStatAt(int i, SQLStat s) { lst[i] = s; };
	
	return stats(addStat, addStatAt, getStat);
}
	
void printSQLSchema(Schema schema, str dbName) {
  Place p = <sql(), dbName>;
  set[str] es = schema.placement[p];
  println(pp(schema2sql(schema, p, es, doForeignKeys = false)));
}

 SQLStat attrs2create(str e, rel[str, str] attrs, Schema schema) {
  	return create(tableName(e), [typhonIdColumn(e)]
      + [column(columnName(attr, e), typhonType2SQL(typ), []) | <str attr, str typ> <- attrs, 
      		typ notin schema.customs<0>]
      + [column(columnName(attr, e, typ, element), typhonType2SQL(elementType), []) | <str attr, str typ> <- attrs,
      	 typ in schema.customs<0>, <str typ, str element, str elementType> <- schema.customs]
      , [primaryKey(typhonId(e))]);
}
 
  // ugh...
  int createOfEntity(str entity, Stats theStats) {
    list[SQLStat] stats = theStats.get();
    for (int i <- [0..size(stats)]) {
      if (stats[i] is create, stats[i].table == tableName(entity)) {
        return i;
      }
    }
    theStats.add(dropTable([tableName(entity)], true, [])); 
    theStats.add(create(tableName(entity), [], []));
    return size(theStats.get()) - 1;
    //assert false: "Could not find create statement for entity <entity>";
  }
  
  void illegal(Rel r) {
    throw "Illegal relation: <r>";
  }
  
  // NB: we add foreign key constraints with alter table to avoid cyclic reference issues.
  
  void addCascadingForeignKey(str from, str fromRole, str to, str toRole, list[ColumnConstraint] cs, Stats stats, bool doForeignKeys) {
    kid = createOfEntity(to, stats);
    fk = fkName(from, to, toRole == "" ? fromRole : toRole);
    list[SQLStat] statsSoFar = stats.get();
    SQLStat stat = statsSoFar[kid];
    stat.cols += [ column(fk, typhonIdType(), cs) ];
    stats.addAt(kid, stat);
    if (doForeignKeys)
    	stats.add(alterTable(tableName(to), [addConstraint(foreignKey(fk, tableName(from), typhonId(from), cascade()))])); 
  }
  
  // should we make both fk's the combined primary key, if so, when?
  void addJunctionTable(str from, str fromRole, str to, str toRole, Stats stats, bool doForeignKeys) {
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
    stats.add(dropTable([tbl], true, []));
    stats.add(stat);
  }
  
  list[SQLStat] processRelation(str from, Cardinality fromCard, str fromRole, str toRole, Cardinality toCard, str to, bool contain, bool doForeignKeys = true, Stats stats = initializeStats()) {
    Rel r = <from, fromCard, fromRole, toRole, toCard, to, contain>;
  	switch (<fromCard, toCard, contain>) {
       case <one_many(), one_many(), true>: illegal(r);
       case <one_many(), zero_many(), true>: illegal(r);
       case <one_many(), zero_one(), true>: illegal(r);
       case <one_many(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [], stats, doForeignKeys); // ??? how to enforce one_many?
       
       
       case <zero_many(), one_many(), true>: illegal(r);
       case <zero_many(), zero_many(), true>: illegal(r);
       case <zero_many(), zero_one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [], stats, doForeignKeys);
       
       case <zero_many(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [notNull()], stats, doForeignKeys);

       case <zero_one(), one_many(), true>: illegal(r);
       case <zero_one(), zero_many(), true>: illegal(r);
       case <zero_one(), zero_one(), true>: illegal(r);
       case <zero_one(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [unique(), notNull()], stats, doForeignKeys);
       
       case <\one(), one_many(), true>: illegal(r);
       case <\one(), zero_many(), true>: illegal(r);
       case <\one(), zero_one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [], stats, doForeignKeys);
       case <\one(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [unique(), notNull()], stats, doForeignKeys);
       
       // we realize all cross refs using a junction table.
       case <_, _, false>: addJunctionTable(from, fromRole, to, toRole, stats, doForeignKeys);
       
     }
     return stats.get();
  }
  
  void addJunctionTableOutside(str from, str fromRole, str to, str toRole, Stats stats, bool doForeignKeys) {
    str left = junctionFkName(from, fromRole);
    str right = junctionFkName(to, toRole);
    str tbl = junctionTableName(from, fromRole, to, toRole);
    SQLStat stat = create(tbl, [
      column(left, typhonIdType(), [notNull()]),
      column(right, typhonIdType(), [notNull()])      
    ], [
      foreignKey(left, tableName(from), typhonId(from), cascade()) | doForeignKeys
    ]);
    stats.add(dropTable([tbl], true, []));
    stats.add(stat);
  }

list[SQLStat] schema2sql(Schema schema, Place place, set[str] placedEntities, bool doForeignKeys = true, Stats stats = initializeStats()) {
  //schema.rels = symmetricReduction(schema.rels);
  
  for (str e <- placedEntities) {
     stats.add(dropTable([tableName(e)], true, []) );
  }
     
  for (str e <- placedEntities) {    
  	 stats.add(attrs2create(e, schema.attrs[e], schema));
  }
  

  
  for (r:<str from, Cardinality fromCard, str fromRole, str toRole, Cardinality toCard, str to, bool contain> <- schema.rels
        // first do all the local ones
         , from in placedEntities, to in placedEntities) { 
     	processRelation(from, fromCard, fromRole, toRole, toCard, to, contain, stats = stats, doForeignKeys = doForeignKeys);
  }
  
  for (r:<str from, Cardinality fromCard, str fromRole, str toRole, Cardinality toCard, str to, bool contain> <- schema.rels
        // then relations to outside
         , from in placedEntities, to notin placedEntities) {
     addJunctionTableOutside(from, fromRole, to, toRole, stats, doForeignKeys); 
  } 
  
  return  stats.get();
}

	// DDL operations

  list[SQLStat] createRelation(str from, Cardinality fromCard, str fromRole, str toRole, Cardinality toCard, str to, bool contain, bool doForeignKeys = true) {
    Rel r = <from, fromCard, fromRole, toRole, toCard, to, contain>;
  	switch (<fromCard, toCard, contain>) {
       case <one_many(), one_many(), true>: illegal(r);
       case <one_many(), zero_many(), true>: illegal(r);
       case <one_many(), zero_one(), true>: illegal(r);
       case <one_many(), \one(), true>: return addOnlyCascadingForeignKey(from, fromRole, to, toRole, [], doForeignKeys); // ??? how to enforce one_many?
       
       
       case <zero_many(), one_many(), true>: illegal(r);
       case <zero_many(), zero_many(), true>: illegal(r);
       case <zero_many(), zero_one(), true>: addOnlyCascadingForeignKey(from, fromRole, to, toRole, [], doForeignKeys);
       
       case <zero_many(), \one(), true>: return addOnlyCascadingForeignKey(from, fromRole, to, toRole, [notNull()], doForeignKeys);

       case <zero_one(), one_many(), true>: illegal(r);
       case <zero_one(), zero_many(), true>: illegal(r);
       case <zero_one(), zero_one(), true>: illegal(r);
       case <zero_one(), \one(), true>: addOnlyCascadingForeignKey(from, fromRole, to, toRole, [unique(), notNull()], doForeignKeys);
       
       case <\one(), one_many(), true>: illegal(r);
       case <\one(), zero_many(), true>: illegal(r);
       case <\one(), zero_one(), true>: return addOnlyCascadingForeignKey(from, fromRole, to, toRole, [], doForeignKeys);
       case <\one(), \one(), true>: return addOnlyCascadingForeignKey(from, fromRole, to, toRole, [unique(), notNull()], doForeignKeys);
       
       // we realize all cross refs using a junction table.
       case <_, _, false>: return addOnlyJunctionTable(from, fromRole, to, toRole, doForeignKeys);
       
     }
     illegal(r);
  }
  
  list[SQLStat] addOnlyCascadingForeignKey(str from, str fromRole, str to, str toRole, list[ColumnConstraint] cs, bool doForeignKeys) {
  	list[SQLStat] stats = [];
    fk = fkName(from, to, toRole == "" ? fromRole : toRole);
    stats += alterTable(tableName(to), [addColumn(column(fk, typhonIdType(), cs))]);
	if (doForeignKeys)
    	stats += alterTable(tableName(to), [addConstraint(foreignKey(fk, tableName(from), typhonId(from), cascade()))]);
    return stats; 
  }

  // should we make both fk's the combined primary key, if so, when?
  list[SQLStat] addOnlyJunctionTable(str from, str fromRole, str to, str toRole, bool doForeignKeys) {
    list[SQLStat] stats = [];
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
    stats += dropTable([tbl], true, []);
    stats += stat;
    return stats;
  }

