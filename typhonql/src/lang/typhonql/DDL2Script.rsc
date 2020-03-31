module lang::typhonql::DDL2Script


import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import lang::typhonql::Script;
import lang::typhonql::Session;
import lang::typhonql::TDBC;
import lang::typhonql::Order;
import lang::typhonql::Normalize;

import lang::typhonql::Insert2Script;
//import lang::typhonql::Update2Script;
import lang::typhonql::References;
import lang::typhonql::Query2Script;



import lang::typhonql::relational::SQL;
import lang::typhonql::relational::Util;
import lang::typhonql::relational::SQL2Text;
import lang::typhonql::relational::Query2SQL;

import lang::typhonql::mongodb::Query2Mongo;
import lang::typhonql::mongodb::DBCollection;

import IO;
import List;

Script ddl2script((Request) `create <EId eId> at <Id dbName>`, Schema s) {
  Script scr = script([]);
  if (p:<db, name> <- s.placement<0>, name == "<dbName>") {
	switch(db) {
		case sql(): {
			SQLStat stat = create(tableName("<eId>"), [typhonIdColumn("<eId>")], []);
			scr += step(name, sql(stat), ());
		}
		case mongodb(): {
			scr += step(name, mongo(createCollection(name, "<eId>")), ());
		}
	}
  }
  return scr;
}

Script ddl2script((Request) `drop <EId eId>`, Schema s) {
  Script scr = script([]);
  if (p:<db, name> <- s.placement<0>, name == "<dbName>") {
	switch(db) {
		case sql(): {
			SQLStat stat = dropTable([tableName("<eId>")], true, []);
			scr += step(name, sql(stat), ());
		}
		case mongodb(): {
			scr += step(name, mongo(dropCollection(name, "<eId>")), ());
		}
	}
  }
  return scr;
}