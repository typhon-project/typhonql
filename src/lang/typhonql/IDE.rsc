module lang::typhonql::IDE

import lang::typhonql::mongodb::DBCollection;
import lang::typhonql::relational::SQL;
import lang::typhonql::relational::SQL2Text;
import lang::typhonql::Compiler;

import lang::typhonml::TyphonML;
import lang::typhonml::Util;

import lang::typhonql::TDBC;
import lang::typhonql::WorkingSet;

import lang::ecore::IO;

import util::IDE;
import ParseTree;
import IO;


@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java Model bootTyphonQL(type[Model] model);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java WorkingSet toMongoDB(str dbName, list[CollMethod] calls);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java WorkingSet toSQL(str dbName, list[str] statements);

WorkingSet toSQL(str dbName, list[SQLStat] statements) = toSQL([ pp(s) | SQLStat s <- statements ]);

private str TYPHONQL = "TyphonQL";

void main() {
  
  registerLanguage(TYPHONQL, "tql", start[Request](str src, loc org) {
    return parse(#start[Request], src, org);
  });
  
  // fake it for now.
  Model schema = load(#Model, |project://typhonql/src/lang/typhonml/mydb4.xmi|); 
  
  // call this in the parse handler or from a menu to avoid race conditions
  // with the rest of the platform.
  //bootTyphonQL(#Model);
  
  registerContributions(TYPHONQL, {
    popup(menu("TyphonQL", [
      action("Execute",  void ((&T<:Tree) tree, loc selection) {
        println("Hello World!");
      }),
      action("Show partitioning",  void ((&T<:Tree) tree, loc selection) {
        println("Partitioning!");
      })
    ]))
  }); 
  
  
}

