module lang::typhonql::Session

alias EntityModels = rel[str name, rel[str name, str \type] attributes, rel[str name, str entity] relations];

alias Session = tuple[
	void (str resultId, str dbName, str query, map[str param, tuple[str resultSet, str \type, str fieldName] field] bindings) executeQuery,
	void (str resultId, str dbName, str query, map[str param, tuple[str resultSet, str \type, str fieldName] field] bindings) executeUpdate,
    str (str result, rel[str name, str \type] entities, EntityModels models) read,
    void () done
];

@reflect
@javaClass{nl.cwi.swat.typhonql.backend.rascal.TyphonSession}
java Session newSession(rel[str dbName, str dbType, str server, int port, str user, str password] databases);