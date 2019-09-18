module lang::typhonql::Bridge


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
java ResultSet executeQuery(str polystoreId, str dbName, str sql);

@javaClass{nl.cwi.swat.typhonql.Bridge}
java int executeUpdate(str polystoreId, str dbName, str sql);


/*
 * MongoDB
 */
 

alias Doc = map[str field, value val];

@javaClass{nl.cwi.swat.typhonql.Bridge}
java void createCollection(str polystoreId, str dbName, str collectionName);

@javaClass{nl.cwi.swat.typhonql.Bridge}
java void drop(str polystoreId, str dbName, str collectionName);

@javaClass{nl.cwi.swat.typhonql.Bridge}
java void insertOne(str polystoreId, str dbName, str collectionName, Doc doc);

@javaClass{nl.cwi.swat.typhonql.Bridge}
java void deleteOne(str polystoreId, str dbName, str collectionName, Doc doc);

@javaClass{nl.cwi.swat.typhonql.Bridge}
java list[Doc] find(str polystoreId, str dbName, str collectionName, Doc pattern);


alias UpdateResult = tuple[int matchedCount, int modifiedCount];

@javaClass{nl.cwi.swat.typhonql.Bridge}
java UpdateResult updateOne(str polystoreId, str dbName, str collectionName, Doc pattern, Doc update);

@javaClass{nl.cwi.swat.typhonql.Bridge}
java UpdateResult updateMany(str polystoreId, str dbName, str collectionName, Doc pattern, Doc update);


