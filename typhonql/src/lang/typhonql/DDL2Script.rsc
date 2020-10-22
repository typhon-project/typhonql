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

module lang::typhonql::DDL2Script


import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::Script;
import lang::typhonql::Session;
import lang::typhonql::TDBC;
import lang::typhonql::Order;
import lang::typhonql::Normalize;

import lang::typhonql::util::Log;

import lang::typhonql::relational::SQL;
import lang::typhonql::relational::Util;
import lang::typhonql::relational::SQL2Text;
import lang::typhonql::relational::Query2SQL;
import lang::typhonql::relational::SQL2Text;
import lang::typhonql::relational::SchemaToSQL;

import lang::typhonql::mongodb::Query2Mongo;
import lang::typhonql::mongodb::DBCollection;

import lang::typhonql::cassandra::Schema2CQL;
import lang::typhonql::cassandra::CQL2Text;

import lang::typhonql::neo4j::Neo;
import lang::typhonql::neo4j::Neo2Text;
import lang::typhonql::neo4j::NeoUtil;


import IO;
import List;
import util::Maybe;

Script ddl2script(Request req, Schema s, Log log = noLog) {
	Script script = ddl2scriptAux(req, s, log = log);
	script.steps = script.steps + [ finish() ];
	return script;
}

Script ddl2scriptAux((Request) `create <EId eId> at <Id dbName>`, Schema s, Log log = noLog) {
  if (p:<db, name> <- s.placement<0>, name == "<dbName>") {
     return createEntity(p, "<eId>", s, log=log);
  }
  throw "Not found db <dbName>";
}

Script createEntity(p:<sql(), str dbName>, str entity, Schema s, Log log = noLog) {
	SQLStat stat = create(tableName(entity), [typhonIdColumn(entity)], []);
	return script([step(dbName, sql(executeStatement(dbName, pp(stat))), ())]);
}

Script createEntity(p:<mongodb(), str dbName>, str entity, Schema s, Log log = noLog) {
	return script([step(dbName, mongo(createCollection(dbName, entity)), ())]);
}

Script createEntity(p:<neo4j(), str dbName>, str entity, Schema s, Log log = noLog) {
	// Neo4j is schemaless
	return [];
}

default Script createEntity(p:<db, str dbName>, str entity, Schema s, Log log = noLog) {
	throw "Unrecognized backend: <db>";
}

Script ddl2scriptAux((Request) `create <EId eId>.<Id attribute> : <Type ty>`, Schema s, Log log = noLog) {
  if (<p:<db, dbName>, entity> <- s.placement, entity == "<eId>") {
	return createAttribute(p, entity, "<attribute>", "<ty>", s, log = log);
  }
  throw "Not found entity <eId>";
}

Script createAttribute(p:<sql(), str dbName>, str entity, str attribute, str ty, Schema s, Log log = noLog) {
	SQLStat stat = alterTable(tableName(entity), [addColumn(column(columnName(attribute, entity), typhonType2SQL(ty), []))]);
	return script([step(dbName, sql(executeStatement(dbName, pp(stat))), ())]);
}

Script createAttribute(p:<mongodb(), str dbName>, str entity, str attribute, str ty, Schema s, Log log = noLog) {
	return script([]);
}

Script createAttribute(p:<neo4j(), str dbName>, str entity, str attribute, str ty, Schema s, Log log = noLog) {
	return script([]);
}

Script ddl2scriptAux((Request) `create <EId eId>.<Id attribute> : <Type ty> forKV <Id kvDb>`, Schema s, Log log = noLog) {
  if (<p:<db, dbName>, entity> <- s.placement, entity == "<eId>") {
  	str originalEntity = "<eId>";
  	str db = "<kvDb>";
  	str role = keyValRole(db, originalEntity);
  	str kvEntity = keyValEntity(db, originalEntity);
  
  	CQLColumnDefinition attributeCol =
  		cColumnDef(cColName(kvEntity, "<attribute>"), type2cql("<ty>"));
  	CQLColumnDefinition relCol = cColumnDef(cColName(kvEntity, role), cUUID());
  
  	steps = [];
  
  	if (<q:<cassandra(), dbName>, entity> <- s.placement, entity == kvEntity) {
  		CQLStat cqlStat = cAlterTable(cTableName(entity),  cAdd([attributeCol, relCol]));
  		steps += step(db, cassandra(cExecuteGlobalStatement(db, pp(cqlStat))), ());
  	} else {
    	CQLStat cqlStat = cCreateTable(cTableName(kvEntity), [attributeCol, relCol]); 
    	steps += step(db, cassandra(cExecuteGlobalStatement(db, pp(cqlStat))), ());
  	}
   
  	Script relScript = createRelation(p, originalEntity, role, kvEntity, \one(), true, Maybe::nothing(), s, log = log);
  	steps += relScript.steps;
  	return script(steps);
  }
  throw "Not found entity <eId>";
}


default Script createAttribute(p:<db, str dbName>, str entity, str attribute, str ty, Schema s, Log log = noLog) {
	throw "Unrecognized backend: <db>";
}

Script ddl2scriptAux((Request) `create <EId eId>.<Id relation> ( <Id inverse> ) <Arrow arrow> <EId targetId> [ <CardinalityEnd lower> .. <CardinalityEnd upper>]`, Schema s, Log log = noLog) {
  if (<p:<db, dbName>, entity> <- s.placement, entity == "<eId>") {
	return createRelation(p, entity, "<relation>", "<targetId>", toCardinality("<lower>", "<upper>"), (Arrow) `:-\>` := arrow, just("<inverse>"), s, log = log);
  }
  throw "Not found entity <eId>";
}

Script ddl2scriptAux((Request) `create <EId eId>.<Id relation> <Arrow arrow> <EId targetId> [ <CardinalityEnd lower> .. <CardinalityEnd upper>]`, Schema s, Log log = noLog) {
  if (<p:<db, dbName>, entity> <- s.placement, entity == "<eId>") {
  	return createRelation(p, entity, "<relation>", "<targetId>", toCardinality("<lower>", "<upper>"), (Arrow) `:-\>` := arrow, Maybe::nothing(), s, log = log);
  }
  throw "Not found entity <eId>";
}

Script createRelation(p:<sql(), str dbName>, str entity, str relation, str targetEntity, Cardinality fromCard, bool containment, Maybe[str] inverse, Schema s, Log log = noLog) {
	list[Step] steps = [];
	// where to get the roles? apparently they are in the ML model but not in the DDL create relation operation
 	// we designed
 	
 	//processRelation(entity, fromCard, fromRole, toRole, toCard, targetEntity, containment);
 	Cardinality toCard = zero_one();
 	//str inverseName = "<relation>^";
 	str inverseName = "";
 	if (just(iname) := inverse) {
 		if (r:<targetEntity, Cardinality c, iname, _, _, _, _> <- schema.rels) { 
        	toCard = c;
	    	inverseName = iname;    
	    }
        else
        	throw "Referred inverse does not exist";
 	}
 	list[SQLStat] stats = createRelation(entity, fromCard, relation, "<relation>^", toCard, targetEntity, containment);
 	for (SQLStat stat <- stats) {
    	log("[ddl2scripr-create-relation/sql/<dbName>] generating <pp(stat)>");
    	steps += step(dbName, sql(executeStatement(dbName, pp(stat))), ());
    }   
    return script(steps);
}

Script createRelation(p:<mongodb(), str dbName>, str entity, str relation, str targetEntity, Cardinality fromCard, bool containment, Maybe[str] inverse, Schema s, Log log = noLog) {
	return script([]);
}

Script createRelation(p:<neo4j(), str dbName>, str entity, str relation, str targetEntity, Cardinality fromCard, bool containment, Maybe[str] inverse, Schema s, Log log = noLog) {
	return script([]);
}

default Script createRelation(p:<db, str dbName>,  str entity, str relation, str targetEntity, Cardinality fromCard, bool containment, Maybe[str] inverse, Schema s, Log log = noLog) {
	throw "Unrecognized backend: <db>";
}

Script ddl2scriptAux((Request) `drop <EId eId>`, Schema s, Log log = noLog) {
  if (<p:<db, dbName>, entity> <- s.placement, entity == "<eId>") {
	return dropEntity(p, entity, s, log = log);
  }
  throw "Not found entity <eId>";
}

Script dropEntity(p:<sql(), str dbName>, str entity, Schema s, Log log = noLog) {
	SQLStat stat = dropTable([tableName(entity)], true, []);
	return script([step(dbName, sql(executeStatement(dbName, pp(stat))), ())]);
}

Script dropEntity(p:<mongodb(), str dbName>, str entity, Schema s, Log log = noLog) {
	return script([step(dbName, mongo(dropCollection(dbName, entity)), ())]);
}

Script dropEntity(p:<neo4j(), str dbName>, str entity, Schema s, Log log = noLog) {
	
	list[Step] steps = [step(dbName, neo(executeNeoUpdate(dbName, 
		neopp(
			nMatchUpdate(
		    	just(
		    		nMatch(
		    			[
		    				nPattern(nNodePattern("__n1", [], []),
		    		    		[nRelationshipPattern(nDoubleArrow(), "__r1", entity, [], nNodePattern("__n2", [], []))]
		    		    	)], [])),
				nDetachDelete([nVariable("__r1")]), 
				[nLit(nBoolean(true))])))), ())];
				
	// remove only if the vertices can participate in other graph kind of relations
	verticesForEntity = {*vertex | <entity, _, _, _, _, vertex, _> <- s.rels};
	verticesForOthers = {*vertex | <e, _, _, _, _, vertex, _> <- s.rels, <<neo4j(), _>, e> <- s.placement, e!=entity};
	
	toRemove = verticesForEntity - verticesForOthers;
	
    for (e <- toRemove) {
    	steps += [step(dbName, neo(executeNeoUpdate(dbName, 
		neopp(
			nMatchUpdate(
		    	just(
		    		nMatch(
		    			[
		    				nPattern(nNodePattern("__n1", [e], []),[])], [])),
				nDetachDelete([nVariable("__n1")]), 
				[nLit(nBoolean(true))])))), ())];
	}
	
	return script(steps);
}

default Script dropEntity(p:<db, str dbName>, str entity, Schema s, Log log = noLog) {
	throw "Unrecognized backend: <db>";
}

Script ddl2scriptAux((Request) `drop attribute <EId eId>.<Id attribute>`, Schema s, Log log = noLog) {
  if (<p:<db, dbName>, entity> <- s.placement, entity == "<eId>") {
    return dropAttribute(p, entity, "<attribute>", s, log = log);
  }
  else if (<q:<cassandra(), kvBackend>, kvEntity> <- s.placement, entitiy == keyValEntity(kvBackend, entity)) {
  	return dropAttribute(q, kvEntity, "<attribute>", s, log = log);
  }
  else
  	throw "Not found entity <eId>";
}

Script dropAttribute(p:<sql(), str dbName>, str entity, str attribute, Schema s, Log log = noLog) {
	SQLStat stat = alterTable(tableName(entity), [dropColumn(columnName(attribute, entity))]);
	return script([step(dbName, sql(executeStatement(dbName, pp(stat))), ())]);
}

Script dropAttribute(p:<mongodb(), str dbName>, str entity, str attribute, Schema s, Log log = noLog) {
	Call call = mongo(
				findAndUpdateMany(dbName, entity, "{}", "{$unset: { \"<attribute>\" : 1}}"));
	return script([step(dbName, call, ())]);
}

Script dropAttribute(p:<neo4j(), str dbName>, str entity, str attribute, Schema s, Log log = noLog) {
	Call call = 
	 neo(executeNeoUpdate(dbName, 
		neopp(
		 \nMatchUpdate(
  			just(nMatch
  				([nPattern(nNodePattern("__n1", [], []), [nRelationshipPattern(nDoubleArrow(), "__r1",  entity, [], nNodePattern("__n2", [], []))])], [])),
			nSet([nSetPlusEquals("__r1", nMapLit((graphPropertyName("<attribute>", entity) : nLit(nNull()))))]),
			[nLit(nBoolean(true))]))));
	
	return script([step(dbName, call, ())]);
}

Script dropAttribute(p:<cassandra(), str dbName>, str entity, str attribute, Schema s, Log log = noLog) {
	CQLStat cqlStat = cAlterTable(cTableName(entity),  cDrop([cColName(entity, "<attribute>")])); 
    return script([step(db, cassandra(cExecuteGlobalStatement(db, pp(cqlStat))), ())]);
}

default Script dropAttribute(p:<db, str dbName>, str entity, str attribute, Schema s, Log log = noLog) {
	throw "Unrecognized backend: <db>";
}

Script ddl2scriptAux((Request) `drop relation <EId eId>.<Id relation>`, Schema s, Log log = noLog) {
  if (<p:<db, dbName>, entity> <- s.placement, entity == "<eId>") {
  	if (<entity, _, "<relation>", str toRole, _, str to, bool containment> <- s.rels) {
		return dropRelation(p, entity, "<relation>", to, toRole, containment, s, log = log);
	}
	else
		throw throw "Relation <eId>.<relation> not found";
  }
  throw "Not found entity <eId>";
}

Script dropRelation(p:<sql(), str dbName>, str entity, str relation, str to, str toRole, bool containment, Schema s, Log log = noLog) {
	doForeignKeys = true;
 	if (containment) {
 		list[Step] steps = [];
 		list[SQLStat] stats = [];
		str fk = fkName(from, to, toRole);
    	if (doForeignKeys)
    		stats += alterTable(tableName(to), [dropConstraint(fk)]);
    	stats += alterTable(tableName(to), [dropColumn(fk)]);	
    	
    	for (SQLStat stat <- stats) {
    		steps += step(dbName, sql(executeStatement(dbName, pp(stat))), ());
    	}  
    	return script(steps);
	} else {
		str tbl = junctionTableName(entity, relation, to, toRole);
		SQLStat stat = dropTable([tbl], true, []);
		return script([step(dbName, sql(executeStatement(dbName, pp(stat))), ())]);	
	}
}

Script dropRelation(p:<mongodb(), str dbName>, str entity, str relation, str to, str toRole, bool containment, Schema s, Log log = noLog) {
	if (containment) {
		return script([]);
	} else {
		Call call = mongo(
				findAndUpdateMany(dbName, entity, "{}", "{$unset: { \"<relation>\" : 1}}"));
		return script([step(dbName, call, ())]);
	}
}

Script dropRelation(p:<neo4j(), str dbName>, str entity, str relation, str to, str toRole, bool containment, Schema s, Log log = noLog) {

}

default Script dropRelation(p:<db, str dbName>,  str entity, str relation, str to, str toRole, bool containment, Schema s, Log log = noLog) {
	throw "Unrecognized backend: <db>";
}

Script ddl2scriptAux((Request) `rename <EId eId> to <EId newName>`, Schema s, Log log = noLog) {
  if (<p:<db, dbName>, entity> <- s.placement, entity == "<eId>") {
     return renameEntity(p, "<eId>", "<newName>", s, log=log);
  }
  throw "Not found entity <eId>";
}

Script renameEntity(p:<sql(), str dbName>, str entity, str newName, Schema s, Log log = noLog) {
	if (<p:<db, dbName>, eId> <- s.placement, entity == eId) {
		return rename(tableName(entity), tableName(newName));
  	}
  	throw "Not found entity <eId>";
}

Script renameEntity(p:<mongodb(), str dbName>, str entity, str newName, Schema s, Log log = noLog) {
	if (<p:<db, dbName>, eId> <- s.placement, entity == eId) {
		return script([step(dbName, mongo(renameCollection(dbName, entity, newName)), ())]);
  	}
  	throw "Not found entity <eId>";
}

Script renameEntity(p:<neo4j(), str dbName>, str entity, str newName, Schema s, Log log = noLog) {
	if (<p:<db, dbName>, eId> <- s.placement, entity == eId) {
		return script([step(dbName, mongo(renameCollection(dbName, entity, newName)), ())]);
  	}
  	throw "Not found entity <eId>";
}


default Script renameEntity(p:<db, str dbName>, str entity, str newName, Schema s, Log log = noLog) {
	throw "Unrecognized backend: <db>";
}

Script ddl2scriptAux((Request) `rename attribute <EId eId>.<Id name> to <Id newName>`, Schema s, Log log = noLog) {
  if (<p:<db, dbName>, entity> <- s.placement, entity == "<eId>") {
	return renameAttribute(p, entity, "<name>", "<newName>", s, log = log);
  }
  throw "Not found entity <eId>";
}

Script renameAttribute(p:<sql(), str dbName>, str entity, str attribute, str newName, Schema s, Log log = noLog) {
	if (<entity, name, str ty> <- s.attrs) {
		SQLStat stat = alterTable(tableName(entity), [renameColumn(column(columnName(attribute, entity), typhonType2SQL(ty), []), columnName(newName, entity))]);
		return script([step(dbName, sql(executeStatement(dbName, pp(stat))), ())]);
	}
	else {
		throw "Attribute <entity>.<attribute> not found";
	}
}

Script renameAttribute(p:<mongodb(), str dbName>, str entity, str attribute, str newName, Schema s, Log log = noLog) {
	Call call = mongo(
				findAndUpdateMany(dbName, entity, "{}", "{ $rename : { \"<attribute>\" : \"<newName>\" }}"));
	return script([step(dbName, call, ())]);
}

Script renameAttribute(p:<neo4j(), str dbName>, str entity, str attribute, str newName, Schema s, Log log = noLog) {

}

default Script renameAttribute(p:<db, str dbName>, str entity, str attribute, str newName, Schema s, Log log = noLog) {
	throw "Unrecognized backend: <db>";
}


Script ddl2scriptAux((Request) `rename relation <EId eId>.<Id name> to <Id newName>`, Schema s, Log log = noLog) {
  if (<p:<db, dbName>, entity> <- s.placement, entity == "<eId>") {
	return renameRelation(p, entity, "<name>", "<newName>", s, log = log);
  }
  throw "Not found entity <eId>";
}

Script renameRelation(p:<sql(), str dbName>, str entity, str relation, str newName, Schema s, Log log = noLog) {
	list[SQLStat] stats = renameRelation(entity, relation, newName, s);
 	for (SQLStat stat <- stats) {
    	log("[ddl2script-rename-relation/sql/<dbName>] generating <pp(stat)>");
    	steps += step(dbName, sql(executeStatement(dbName, pp(stat))), ());
    }   
    return script(steps);
}

Script renameRelation(p:<mongodb(), str dbName>, str entity, str relation, str newName, Schema s, Log log = noLog) {
	Call call = mongo(
				findAndUpdateMany(dbName, entity, "", "{ $rename : { \"<relation>\" : \"<newName>\" }}"));
	return script([step(dbName, call, ())]);
}

Script renameRelation(p:<neo4j(), str dbName>, str entity, str relation, str newName, Schema s, Log log = noLog) {
	
}

default Script renameRelation(p:<db, str dbName>, str entity, str attribute, str newName, Schema s, Log log = noLog) {
	throw "Unrecognized backend: <db>";
}

Script ddl2scriptAux((Request) `create index <Id indexName> for <EId eId>.{ <{Id ","}+ attrs> }`, Schema s, Log log = noLog) {
  if (<p:<db, dbName>, entity> <- s.placement, entity == "<eId>") {
	return createIndex(p, entity, "<entity>_<indexName>", ["<a>" |Id a <- attrs], s, log = log);
  }
  throw "Not found entity <eId>";
}

Script createIndex(p:<sql(), str dbName>, str entity, str indexName, list[str] attributes, Schema s, Log log = noLog) {
	TableConstraint index = index(indexName, regular(), [columnName(attr, entity) | attr <- attributes]);
	SQLStat stat = alterTable(tableName(entity), [addConstraint(index)]);
	return script([step(dbName, sql(executeStatement(dbName, pp(stat))), ())]);
}

Script createIndex(p:<mongodb(), str dbName>, str entity, str indexName, list[str] attributes, Schema s, Log log = noLog) {
	stp = step(dbName, mongo(createIndex(dbName, entity, indexName, "{ <intercalate(", ",["\"<attrOrRef>\": 1"| str attrOrRef <- attributes])>}")), ());
	return script([stp]);
}

Script ddl2scriptAux((Request) `drop index <EId eId>.<Id indexName>`, Schema s, Log log = noLog) {
  if (<p:<db, dbName>, entity> <- s.placement, entity == "<eId>") {
	return dropIndex(p, entity, "<entity>_<indexName>", s, log = log);
  }
  throw "Not found entity <eId>";
}

Script dropIndex(p:<sql(), str dbName>, str entity, str indexName, Schema s, Log log = noLog) {
	SQLStat stat = alterTable(tableName(entity), [Alter::dropIndex(indexName)]);
	return script([step(dbName, sql(executeStatement(dbName, pp(stat))), ())]);
}

Script dropIndex(p:<mongodb(), str dbName>, str entity, str indexName, Schema s, Log log = noLog) {
	println(indexName);
	stp = step(dbName, mongo(dropIndex(dbName, entity, indexName)), ());
	return script([stp]);

}

default Script createIndex(p:<db, str dbName>, str entity, str indexName, list[str] attributes, Schema s, Log log = noLog) {
	throw "Unrecognized backend: <db>";
}



Cardinality toCardinality("1", "*") = one_many();
Cardinality toCardinality("0", "*") = zero_many();
Cardinality toCardinality("0", "1") = zero_one();
Cardinality toCardinality("1", "1") = \one();
default Cardinality toCardinality(str src, str tgt) {
	throw "Unknown cardinality: <src>..<tgt>";
} 	
