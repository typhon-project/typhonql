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
      + [column(columnName(attr, e), typhonType2SQL(typ), typhonType2Constrains(typ)) | <str attr, str typ> <- attrs, 
      		typ notin schema.customs<from>]
      //+ [column(columnName(attr, e, typ, element), typhonType2SQL(elementType), []) | <str attr, str typ> <- attrs,
      //	 <typ, str element, str elementType> <- schema.customs]
      , [primaryKey(typhonId(e))] + indexes(e, attrs, schema));
}


list[TableConstraint] indexes(str e, rel[str, str] attrs, Schema schema) 
    = [
        index("<e>_<attr>_spatial", spatial(), [columnName(attr, e)])
        | <str attr, str typ> <- attrs, typ notin schema.customs<from>, typhonType2SQL(typ) in {polygon(), point()}
    ]
    + [
        index("<e>_<iname>", regular(), [columnName(attr, e) | attr <- columns])
        | <<sql(), str dbName>, e> <- schema.placement, indexSpec(str iname, e, columns) <- schema.pragmas[dbName]
    ];
 
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
    if (doForeignKeys) {
    	stats.add(alterTable(tableName(to), [addConstraint(foreignKey(fk, tableName(from), typhonId(from), cascade()))]));
    } 
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
       case <one_many(), zero_one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [], stats, doForeignKeys); 
       case <one_many(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [], stats, doForeignKeys); 
       
       
       case <zero_many(), one_many(), true>: illegal(r);
       case <zero_many(), zero_many(), true>: illegal(r);
       case <zero_many(), zero_one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [], stats, doForeignKeys);
       case <zero_many(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [notNull()], stats, doForeignKeys);

       case <zero_one(), one_many(), true>: illegal(r);
       case <zero_one(), zero_many(), true>: illegal(r);
       case <zero_one(), zero_one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [unique()], stats, doForeignKeys);
       case <zero_one(), \one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [unique()], stats, doForeignKeys);
       
       case <\one(), one_many(), true>: illegal(r);
       case <\one(), zero_many(), true>: illegal(r);
       case <\one(), zero_one(), true>: addCascadingForeignKey(from, fromRole, to, toRole, [unique(), notNull()], stats, doForeignKeys);
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
    ], [ foreignKey(left, tableName(from), typhonId(from), cascade()) | doForeignKeys ]
     + [ index("<from>_<right>", regular(), [right]) ]
    );
    stats.add(dropTable([tbl], true, []));
    stats.add(stat);
}

void addJunctionTableFromOutside(str from, str fromRole, str to, str toRole, Stats stats, bool doForeignKeys) {
    str left = junctionFkName(from, fromRole);
    str right = junctionFkName(to, toRole);
    str tbl = junctionTableName(from, fromRole, to, toRole);
    SQLStat stat = create(tbl, [
      column(left, typhonIdType(), [notNull()]),
      column(right, typhonIdType(), [notNull()])      
    ], [ foreignKey(right, tableName(to), typhonId(to), cascade()) | doForeignKeys ]
     + [ index("<to>_<left>", regular(), [left]) ]
    );
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


  for (r:<str from, Cardinality fromCard, str fromRole, str toRole, Cardinality toCard, str to, bool contain> <- schema.rels
        // then relations from outside
         , to in placedEntities, from notin placedEntities) {
     addJunctionTableFromOutside(from, fromRole, to, toRole, stats, doForeignKeys); 
  } 
  
  return  stats.get();
}

	// DDL operations
	
list[SQLStat] renameRelation(str from, str relation, str newName, Schema s) {
    if (r: <from, fromCard, relation, toRole, toCard, to, contain> <- s.rels)  {
  		switch (<fromCard, toCard, contain>) {
       		case <one_many(), \one(), true>: return renameOnlyCascadingForeignKey(newName, from, fromRole, to, toRole, []); // ??? how to enforce one_many?
       		case <zero_many(), zero_one(), true>: renameOnlyCascadingForeignKey(newName, from, fromRole, to, toRole, []);
       		case <zero_many(), \one(), true>: return renameOnlyCascadingForeignKey(newName, from, fromRole, to, toRole, [notNull()]);
			case <zero_one(), \one(), true>: renameOnlyCascadingForeignKey(newNamefrom, fromRole, to, toRole, [unique(), notNull()]);
       		case <\one(), zero_one(), true>: return renameOnlyCascadingForeignKey(newName, from, fromRole, to, toRole, []);
       		case <\one(), \one(), true>: return renameOnlyCascadingForeignKey(newName, from, fromRole, to, toRole, [unique(), notNull()]);
            // we realize all cross refs using a junction table.
       		case <_, _, false>: return renameOnlyJunctionTable(newName, from, fromRole, to, toRole);
       		default: illegal(r);
       }
    }
  	throw "Relation <relation> does not exist";
}

list[SQLStat] createRelation(str from, Cardinality fromCard, str fromRole, str toRole, Cardinality toCard, str to, bool contain, bool doForeignKeys = true) {
    Rel r = <from, fromCard, fromRole, toRole, toCard, to, contain>;
  	switch (<fromCard, toCard, contain>) {
       case <one_many(), one_many(), true>: illegal(r);
       case <one_many(), zero_many(), true>: illegal(r);
       case <one_many(), zero_one(), true>: illegal(r);
       case <one_many(), \one(), true>: return addOnlyCascadingForeignKey(from, fromRole, to, toRole, [], doForeignKeys); // ??? how to enforce one_many?
       
       
       case <zero_many(), one_many(), true>: illegal(r);
       case <zero_many(), zero_many(), true>: illegal(r);
       case <zero_many(), zero_one(), true>: return addOnlyCascadingForeignKey(from, fromRole, to, toRole, [], doForeignKeys);
       
       case <zero_many(), \one(), true>: return addOnlyCascadingForeignKey(from, fromRole, to, toRole, [notNull()], doForeignKeys);

       case <zero_one(), one_many(), true>: illegal(r);
       case <zero_one(), zero_many(), true>: illegal(r);
       case <zero_one(), zero_one(), true>: illegal(r);
       case <zero_one(), \one(), true>: return addOnlyCascadingForeignKey(from, fromRole, to, toRole, [unique(), notNull()], doForeignKeys);
       
       case <\one(), one_many(), true>: illegal(r);
       case <\one(), zero_many(), true>: illegal(r);
       case <\one(), zero_one(), true>: return addOnlyCascadingForeignKey(from, fromRole, to, toRole, [], doForeignKeys);
       case <\one(), \one(), true>: return addOnlyCascadingForeignKey(from, fromRole, to, toRole, [unique(), notNull()], doForeignKeys);
       
       // we realize all cross refs using a junction table.
       case <_, _, false>: return addOnlyJunctionTable(from, fromRole, to, toRole, doForeignKeys);
       
     }
     illegal(r);
     return [];
}
  
  
  
list[SQLStat] addOnlyCascadingForeignKey(str from, str fromRole, str to, str toRole, list[ColumnConstraint] cs, bool doForeignKeys) {
  	list[SQLStat] stats = [];
    fk = fkName(from, to, toRole == "" ? fromRole : toRole);
    stats += alterTable(tableName(to), [addColumn(column(fk, typhonIdType(), cs))]);
	if (doForeignKeys)
    	stats += alterTable(tableName(to), [addConstraint(foreignKey(fk, tableName(from), typhonId(from), cascade()))]);
    return stats; 
}
  
list[SQLStat] renameOnlyCascadingForeignKey(str newName, str from, str fromRole, str to, str toRole, list[ColumnConstraint] cs) {
  	list[SQLStat] stats = [];
    fk = fkName(from, to, toRole == "" ? fromRole : toRole);
    //stats += alterTable(tableName(to), [addColumn(column(fk, typhonIdType(), cs))]);
    //renameColumn(column(columnName(attribute, entity), typhonType2SQL(ty), []), columnName(newName, entity))
    stats += alterTable(tableName(to), [renameColumn(column(fk, typhonType2SQL(typhonIdType()), []), fkName(from, to, toRole == "" ? newName : toRole))]);
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
  
list[SQLStat] renameOnlyJunctionTable(str newName, str from, str fromRole, str to, str toRole) {
    list[SQLStat] stats = [];
    str left = junctionFkName(from, fromRole);
    str newLeft = junctionFkName(from, newName);
    str right = junctionFkName(to, toRole);
    str tbl = junctionTableName(from, fromRole, to, toRole);
    str newTbl = junctionFkName(from, newName);
    SQLStat stat1 = renameColumn(column(left, typhonType2SQL(typhonIdType()), []), newLeft);
    SQLStat stat2 = rename(tbl, newTbl);
    stats += stat1;
    stats += stat2;
    return stats;
}
