package nl.cwi.swat.typhonql.backend;

import java.util.Map;

import org.apache.commons.text.StringSubstitutor;
import org.bson.Document;

import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;

public abstract class MongoUpdateExecutor extends UpdateExecutor {

	protected String connectionString;
	protected String dbName;
	protected String collectionName;
	private String query;

	public MongoUpdateExecutor(ResultStore store, Map<String, String> uuids, String collectionName, String query,
			Map<String, Binding> bindings, String connectionString, String dbName) {
		super(store, uuids, bindings);
		this.dbName = dbName;
		this.connectionString = connectionString;
		this.collectionName = collectionName;
		this.query = query;
	}

	@Override
	protected void performUpdate(Map<String, String> values) {
		MongoClient mongoClient = MongoClients.create(connectionString);
		MongoDatabase db = mongoClient.getDatabase(dbName);
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
