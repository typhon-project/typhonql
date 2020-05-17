package nl.cwi.swat.typhonql.backend.mongodb;

import java.util.List;
import java.util.Map;

import org.bson.Document;

import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;
import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.ResultStore;

public class MongoInsertOneExecutor extends MongoUpdateExecutor {

	public MongoInsertOneExecutor(ResultStore store, List<Runnable> updates, Map<String, String> uuids, String collectionName, String query,
			Map<String, Binding> bindings, MongoDatabase db) {
		super(store, updates, uuids, collectionName, query, bindings, db);
	}

	@Override
	protected void performUpdate(MongoCollection<Document> coll, Document resolvedQuery) {
		coll.insertOne(resolvedQuery);
	}

}
