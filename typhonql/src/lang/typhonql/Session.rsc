module lang::typhonql::Session


//public /*const*/ str ID_PARAM = "TYPHON_ID";
//Field generatedIdField() = <"ID_STORE", "", "", "@id">;

alias EntityModels = rel[str name, rel[str name, str \type] attributes, rel[str name, str entity] relations];

alias Path = tuple[str name, str entityType, list[str] path];

alias Session = tuple[
	str (str result, list[Path path] paths) read,
	void () done,
	void (str) newId,
   	SQLOperations sql,
   	MongoOperations mongo
];

//alias Field = tuple[str resultSet, str label, str \type, str fieldName];

data Param
  = field(str resultSet, str label, str \type, str fieldName)
  | generatedId(str name)
  ;

alias Bindings = map[str, Param];

alias SQLOperations = tuple[
	void (str resultId, str dbName, str query, Bindings bindings) executeQuery,
	void (str dbName, str query, Bindings bindings) executeStatement 
];

alias MongoOperations = tuple[
	void (str resultId, str dbName, str collection, str query, Bindings bindings) find,
	void (str resultId, str dbName, str collection, str query, str projection, Bindings bindings) findWithProjection,
	void (str dbName, str coll, str query, Bindings bindings) insertOne,
	void (str dbName, str coll, str query, str update, Bindings bindings) findAndUpdateOne,
	void (str dbName, str coll, str query, Bindings bindings) deleteOne
];


data Connection
 // for now they are the same, but they might be different
 = sqlConnection(str host, int port, str user, str password)
 | mongoConnection(str host, int port, str user, str password)
 ;

@reflect
@javaClass{nl.cwi.swat.typhonql.backend.rascal.TyphonSession}
java Session newSession(map[str, Connection] config);


private int _nameCounter = 0;

str newParam() {
  str p = "param_<_nameCounter>";
  _nameCounter += 1;
  return p;
}

