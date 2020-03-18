module lang::typhonql::Bridge

import lang::typhonql::Session;


/*

This module Bridges the Java DB API world to the TyphonQL world
in Rascal. The bridge is very thin by design, encoding Java
types returned by various API calls as directly as possible in
Rascal so that all (possibly heavy lifting) conversions is done
in Rascal.
*/

// TODO: also expose the analytics features here

/*
 * JDBC
 */
 
 
alias Record = map[str column, value val];
alias ResultSet = list[Record];

@javaClass{nl.cwi.swat.typhonql.Bridge}
java ResultSet executeQuery(str dbName, str sql, Connection conn);

@javaClass{nl.cwi.swat.typhonql.Bridge}
java int executeUpdate(str dbName, str sql, Connection conn);


/*
 * MongoDB
 */
 

alias Doc = map[str field, value val];

@javaClass{nl.cwi.swat.typhonql.Bridge}
java void createCollection(str dbName, str collectionName, Connection conn);

@javaClass{nl.cwi.swat.typhonql.Bridge}
java void drop(str dbName, str collectionName, Connection conn);

@javaClass{nl.cwi.swat.typhonql.Bridge}
java void insertOne(str dbName, str collectionName, Doc doc, Connection conn);

@javaClass{nl.cwi.swat.typhonql.Bridge}
java void deleteOne(str dbName, str collectionName, Doc doc, Connection conn);

@javaClass{nl.cwi.swat.typhonql.Bridge}
java list[Doc] find(str dbName, str collectionName, Doc pattern, Connection conn);


alias UpdateResult = tuple[int matchedCount, int modifiedCount];

@javaClass{nl.cwi.swat.typhonql.Bridge}
java UpdateResult updateOne(str dbName, str collectionName, Doc pattern, Doc update, Connection conn);

@javaClass{nl.cwi.swat.typhonql.Bridge}
java UpdateResult updateMany(str dbName, str collectionName, Doc pattern, Doc update, Connection conn);


