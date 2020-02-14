module lang::typhonql::Session

alias EntityModels = rel[str name, rel[str name, str \type] attributes, rel[str name, str entity] relations];

alias Session = tuple[
	str (str result, rel[str name, str \type] entities, EntityModels models) read,
	void () done,
   	SQLOperations sql,
   	MongoOperations mongo
];

alias Field = tuple[str resultSet, str label, str \type, str fieldName];

alias Bindings = map[str, Field];

alias SQLOperations = tuple[
	void (str resultId, str dbName, str query, Bindings bindings) executeQuery
];

alias MongoOperations = tuple[
	void (str resultId, str dbName, str collection, str query, Bindings bindings) find
];


data Connection
 // for now they are the same, but they might be different
 = sqlConnection(str host, int port, str user, str password)
 | mongoConnection(str host, int port, str user, str password)
 ;

@reflect
@javaClass{nl.cwi.swat.typhonql.backend.rascal.TyphonSession}
java Session newSession(map[str, Connection] config);