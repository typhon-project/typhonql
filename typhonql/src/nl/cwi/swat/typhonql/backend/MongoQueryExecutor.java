package nl.cwi.swat.typhonql.backend;

import java.util.Map;

import org.apache.commons.text.StringSubstitutor;
import org.bson.Document;

import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;

public class MongoQueryExecutor extends QueryExecutor {


	private String connectionString;
	private String dbName;
	private String collectionName;
	private String query;

	public MongoQueryExecutor(ResultStore store, String collectionName, String query,
			Map<String, Binding> bindings, String connectionString, String dbName) {
		super(store, query, bindings);
		this.dbName = dbName;
		this.connectionString = connectionString;
		this.collectionName = collectionName;
		this.query = query;
	}

	@Override
	protected ResultIterator performSelect(Map<String, String> values) {
		MongoClient mongoClient = MongoClients.create(connectionString);
		MongoDatabase db = mongoClient.getDatabase(dbName);
		StringSubstitutor sub = new StringSubstitutor(values);
		String resolvedQuery = sub.replace(query);
		MongoCollection<Document> coll = db.getCollection(collectionName);
		Document pattern = Document.parse(resolvedQuery);
		return new MongoDBIterator(coll.find(pattern));
	}

}
