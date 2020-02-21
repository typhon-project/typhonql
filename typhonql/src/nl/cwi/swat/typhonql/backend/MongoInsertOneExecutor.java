package nl.cwi.swat.typhonql.backend;

import java.util.Map;

import org.bson.Document;

import com.mongodb.client.MongoCollection;

public class MongoInsertOneExecutor extends MongoUpdateExecutor {

	public MongoInsertOneExecutor(ResultStore store, Map<String, String> uuids, String collectionName, String query,
			Map<String, Binding> bindings, String connectionString, String dbName) {
		super(store, uuids, collectionName, query, bindings, connectionString, dbName);
	}

	@Override
	protected void performUpdate(MongoCollection<Document> coll, Document resolvedQuery) {
		coll.insertOne(resolvedQuery);
	}

}
