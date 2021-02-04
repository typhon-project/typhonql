/********************************************************************************
* Copyright (c) 2018-2020 CWI & Swat.engineering 
*
* This program and the accompanying materials are made available under the
* terms of the Eclipse Public License 2.0 which is available at
* http://www.eclipse.org/legal/epl-2.0.
*
* This Source Code may also be made available under the following Secondary
* Licenses when the conditions for such availability set forth in the Eclipse
* Public License, v. 2.0 are satisfied: GNU General Public License, version 2
* with the GNU Classpath Exception which is
* available at https://www.gnu.org/software/classpath/license.html.
*
* SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0
********************************************************************************/

module lang::typhonql::Session


//public /*const*/ str ID_PARAM = "TYPHON_ID";
//Field generatedIdField() = <"ID_STORE", "", "", "@id">;

alias EntityModels = rel[str name, rel[str name, str \type] attributes, rel[str name, str entity] relations];

alias Path = tuple[str dbName, str var, str entityType, list[str] path];

alias Session = tuple[
	ResultTable () getResult,
	value () getJavaResult,
	void (list[Path path] paths) readAndStore,
   	void (str className, str classContents, list[Path path] paths, list[str] finalColumnNames) javaReadAndStore, 
	void () finish,
	void () done,
	str (str) newId,
	bool () hasAnyExternalArguments,
	bool () hasMoreExternalArguments,
	void () nextExternalArguments,
	void (str) report,
	SQLOperations sql,
   	MongoOperations mongo,
   	CassandraOperations cassandra,
   	Neo4JOperations neo,
   	NlpOperations nlp 
];

alias ResultTable
  = tuple[list[str] columnNames, list[list[value]] values];

//alias Field = tuple[str resultSet, str label, str \type, str fieldName];

data Param
  = field(str resultSet, str label, str \type, str fieldName)
  | generatedId(str name)
  ;

alias Bindings = map[str, Param];

alias SQLOperations = tuple[
	void (str resultId, str dbName, str query, Bindings bindings, list[Path] paths) executeQuery,
	void (str dbName, str query, Bindings bindings) executeStatement,
	void (str dbName, str query, Bindings bindings) executeGlobalStatement
];

alias CassandraOperations = tuple[
	void (str resultId, str dbName, str query, Bindings bindings, list[Path] paths) executeQuery,
	void (str dbName, str query, Bindings bindings) executeStatement,
	void (str dbName, str query, Bindings bindings) executeGlobalStatement
];

alias Neo4JOperations = tuple[
	void (str resultId, str dbName, str query, Bindings bindings, list[Path] paths) executeMatch,
	void (str dbName, str query, Bindings bindings) executeUpdate
];

alias MongoOperations = tuple[
	void (str resultId, str dbName, str collection, str query, Bindings bindings, list[Path] paths) find,
	void (str resultId, str dbName, str collection, str query, str projection, Bindings bindings, list[Path] paths) findWithProjection,
	void (str dbName, str coll, str query, Bindings bindings) insertOne,
	void (str dbName, str coll, str query, str update, Bindings bindings) findAndUpdateOne,
	void (str dbName, str coll, str query, str update, Bindings bindings) findAndUpdateMany,
	void (str dbName, str coll, str query, Bindings bindings) deleteOne,
	void (str dbName, str coll, str query, Bindings bindings) deleteMany,
	void (str dbName, str coll) createCollection,
    void (str dbName, str coll, str indexName, str keys) createIndex,
	void (str dbName, str coll, str newName) renameCollection,
	void (str dbName, str coll, str indexName) dropCollection,
	void (str dbName, str indexName) dropIndex,
	void (str dbName) dropDatabase,
	void (str resultId, str dbName, str collection, list[str] stages, Bindings bindings, list[Path] paths) aggregate
];

alias NlpOperations = tuple[
	void (str json, Bindings bindings) process,
	void (str json, Bindings bindings) delete,
	void (str json, Bindings bindings, list[Path] paths) query
];


data Connection
 // for now they are the same, but they might be different
 = mariaConnection(str host, int port, str user, str password)
 | mongoConnection(str host, int port, str user, str password)
 | cassandraConnection(str host, int port, str user, str password)
 | neoConnection(str host, int port, str user, str password)
 | nlpConnection(str host, int port, str user, str password)
 ;

@reflect
@javaClass{nl.cwi.swat.typhonql.backend.rascal.TyphonSession}
java Session newSession(map[str, Connection] config, map[str uuid, str contents] blobMap = ());

@reflect
@javaClass{nl.cwi.swat.typhonql.backend.rascal.TyphonSession}
java Session newSessionWithArguments(map[str, Connection] config, 
	list[str] columnNames, list[str] columnTypes, list[list[str]] values, map[str uuid, str contents] blobMap = ());

private int _nameCounter = 0;

str newParam() {
  str p = "param_<_nameCounter>";
  _nameCounter += 1;
  return p;
}
