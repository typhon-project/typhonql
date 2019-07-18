module lang::typhonql::Bridge

import lang::typhonql::WorkingSet;
import lang::typhonql::mongodb::DBCollection;


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
java Doc find(str dbName, Doc pattern);

@javaClass{nl.cwi.swat.typhonql.Bridge}
java Doc find(str dbName, Doc pattern, Doc projection);

@javaClass{nl.cwi.swat.typhonql.Bridge}
java Doc findAndModify(str dbName, Doc pattern, Doc update);


