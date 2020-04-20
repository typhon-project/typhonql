package nl.cwi.swat.typhonql.backend;

import java.util.Map;

import org.apache.commons.text.StringSubstitutor;
import org.bson.Document;

import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;

public abstract class MongoUpdateExecutor extends UpdateExecutor {

	protected MongoDatabase db;
	protected String collectionName;
	private String query;

	public MongoUpdateExecutor(ResultStore store, Map<String, String> uuids, String collectionName, String query,
			Map<String, Binding> bindings, MongoDatabase db) {
		super(store, uuids, bindings);
		this.db = db;
		this.collectionName = collectionName;
		this.query = query;
	}

	@Override
	protected void performUpdate(Map<String, String> values) {
		MongoCollection<Document> coll = db.getCollection(collectionName);
		performUpdate(coll, resolveQuery(values));
		
	}

	protected abstract void performUpdate(MongoCollection<Document> coll, Document resolveQuery);

	protected void performUpdate(MongoCollection<Document> coll, Document resolveQuery, Document update) {

	}

	protected Document resolveQuery(Map<String, String> values) {
		StringSubstitutor sub = new StringSubstitutor(values);
		String resolvedQuery = sub.replace(query);
		Document pattern = Document.parse(resolvedQuery);
		return pattern;
	}

}
