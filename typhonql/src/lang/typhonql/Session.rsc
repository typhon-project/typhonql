module lang::typhonql::Session

alias EntityModels = rel[str name, rel[str name, str \type] attributes, rel[str name, str entity] relations];

alias Session = tuple[
	str (str result, rel[str name, str \type] entities, EntityModels models) read,
	void () done,
   	SQLOperations sql,
   	MongoOperations mongo
];

alias SQLOperations = tuple[
	void (str resultId, str host, int port, str user, str password, str dbName, str query, map[str param, tuple[str resultSet, str \type, str fieldName] field] bindings) executeQuery
];

alias MongoOperations = tuple[
	void (str resultId, str host, int port, str user, str password, str dbName, str query, map[str param, tuple[str resultSet, str \type, str fieldName] field] bindings) find
];


data Connection
 = sqlConnection(str host, int port, str user, str password)
 | mongoConnection(str host, int port, str user, str password)
 ;

@reflect
@javaClass{nl.cwi.swat.typhonql.backend.rascal.TyphonSession}
java Session newSession(map[str, Connection] config);