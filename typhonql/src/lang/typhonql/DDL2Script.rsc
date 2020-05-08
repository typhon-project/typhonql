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
import lang::typhonql::relational::Schema2SQL;

import lang::typhonql::mongodb::Query2Mongo;
import lang::typhonql::mongodb::DBCollection;

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
	Call call = mongo(
				findAndUpdateMany(dbName, entity, "", "{$set: { \"<attribute>\" : null}}"));
	return script([step(dbName, call, ())]);
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
	return createRelation(p, entity, "<relation>", "<targetId>", toCardinality("<lower>", "<upper>"), (Arrow) `:-\>` := arrow, nothing(), s, log = log);
  }
  throw "Not found entity <eId>";
}

Script createRelation(p:<sql(), str dbName>, str entity, str relation, Cardinality fromCard, bool containment, Maybe[str] inverse, Schema s, Log log = noLog) {
	list[Step] steps = [];
	// where to get the roles? apparently they are in the ML model but not in the DDL create relation operation
 	// we designed
 	
 	//processRelation(entity, fromCard, fromRole, toRole, toCard, targetEntity, containment);
 	Cardinality toCard = zero_one();
 	str inverseName = "<relation>^";
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

Script createRelation(p:<mongodb(), str dbName>, str entity, str relation,Cardinality fromCard, bool containment, Maybe[str] inverse, Schema s, Log log = noLog) {
	Call call = mongo(
				findAndUpdateMany(dbName, entity, "", "{$set: { \"<relation>\" : null}}"));
	return script([step(dbName, call, ())]);
}

default Script createRelation(p:<db, str dbName>,  str entity, str relation,Cardinality fromCard, bool containment, Maybe[str] inverse, Schema s, Log log = noLog) {
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

default Script dropEntity(p:<db, str dbName>, str entity, Schema s, Log log = noLog) {
	throw "Unrecognized backend: <db>";
}

Script ddl2scriptAux((Request) `drop attribute <EId eId>.<Id attribute>`, Schema s, Log log = noLog) {
  if (<p:<db, dbName>, entity> <- s.placement, entity == "<eId>") {
	return dropAttribute(p, entity, "<attribute>", s, log = log);
  }
  throw "Not found entity <eId>";
}

Script dropAttribute(p:<sql(), str dbName>, str entity, str attribute, str ty, Schema s, Log log = noLog) {
	SQLStat stat = alterTable(tableName(entity), [dropColumn(columnName(attribute, entity))]);
	return script([step(dbName, sql(executeStatement(dbName, pp(stat))), ())]);
}

Script dropAttribute(p:<mongodb(), str dbName>, str entity, str attribute, Schema s, Log log = noLog) {
	Call call = mongo(
				findAndUpdateMany(dbName, entity, "", "{$unset: { \"<attribute>\" : 1}}"));
	return script([step(dbName, call, ())]);
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

Script dropRelation(p:<sql(), str dbName>, str entity, str relation, str to, str toRole, str containment, Schema s, Log log = noLog) {
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
		str tbl = junctionTableName(from, fromRole, to, toRole);
		SQLStat stat = dropTable([tbl], true, []);
		return script([step(dbName, sql(executeStatement(dbName, pp(stat))), ())]);	
	}
}

Script dropRelation(p:<mongodb(), str dbName>, str entity, str relation, str to, str toRole, str containment, Schema s, Log log = noLog) {
	if (containment) {
		return script([]);
	} else {
		Call call = mongo(
				findAndUpdateMany(dbName, entity, "", "{$unset: { \"<fromRole>\" : 1}}"));
		return script([step(dbName, call, ())]);
	}
}

default Script dropRelation(p:<db, str dbName>,  str entity, str relation, str to, str toRole, str containment, Schema s, Log log = noLog) {
	throw "Unrecognized backend: <db>";
}

Script ddl2scriptAux((Request) `rename <EId eId> to <EId newName>`, Schema s, Log log = noLog) {
  if (<p:<db, dbName>, entity> <- s.placement, entity == "<eId>") {
     return renameEntity(p, "<eId>", "<newName>", s, log=log);
  }
  throw "Not found entity <eId>";
}

Script renameEntity(p:<sql(), str dbName>, str entity, str newName, Schema s, Log log = noLog) {
	if (<p:<db, dbName>, entity> <- s.placement, entity == "<eId>") {
		return rename(tableName(entity), tableName(newName));
  	}
  	throw "Not found entity <eId>";
}

Script renameEntity(p:<mongodb(), str dbName>, str entity, str newName, Schema s, Log log = noLog) {
	if (<p:<db, dbName>, entity> <- s.placement, entity == "<eId>") {
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
				findAndUpdateMany(dbName, entity, "", "{ $rename : { \"<attribute>\" : \"<newName>\" }}"));
	return script([step(dbName, call, ())]);
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

default Script renameRelation(p:<db, str dbName>, str entity, str attribute, str newName, Schema s, Log log = noLog) {
	throw "Unrecognized backend: <db>";
}

Cardinality toCardinality("ONE_MANY") = one_many();
Cardinality toCardinality("ZERO_MANY") = zero_many();
Cardinality toCardinality("ZERO_ONE") = zero_one();
Cardinality toCardinality("ONE") = \one();
default Cardinality toCardinality(str card) {
	throw "Unknown cardinality: <card>";
} 	

