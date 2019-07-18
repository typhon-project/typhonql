module lang::typhonql::Bridge


// TODO: also expose the analytics features here

/*
 * JDBC
 */
 
 
alias Record = map[str column, value val];
alias ResultSet = list[Record];

@javaClass{nl.cwi.swat.typhonql.Bridge}
java ResultSet executeQuery(str dbName, str sql);

@javaClass{nl.cwi.swat.typhonql.Bridge}
java int executeUpdate(str dbName, str sql);


/*
 * MongoDB
 */
 
 
alias Doc = map[str field, value val];

@javaClass{nl.cwi.swat.typhonql.Bridge}
java void createCollection(str dbName, str collectionName);

@javaClass{nl.cwi.swat.typhonql.Bridge}
java void drop(str dbName, str collectionName);

@javaClass{nl.cwi.swat.typhonql.Bridge}
java void insertOne(str dbName, str collectionName, Doc doc);

@javaClass{nl.cwi.swat.typhonql.Bridge}
java void deleteOne(str dbName, str collectionName, Doc doc);

@javaClass{nl.cwi.swat.typhonql.Bridge}
java list[Doc] find(str dbName, str collectionName, Doc pattern);

alias UpdateResult = tuple[int matchedCount, int modifiedCount];

@javaClass{nl.cwi.swat.typhonql.Bridge}
java UpdateResult updateMany(str dbName, str collectionName, Doc pattern, Doc update);


