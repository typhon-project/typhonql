package nl.cwi.swat.typhonql.backend;

import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

import org.apache.commons.text.StringSubstitutor;
import org.bson.Document;

import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;

import nl.cwi.swat.typhonql.backend.rascal.Path;

public class MongoQueryWithProjectionExecutor extends QueryExecutor {


	private String connectionString;
	private String dbName;
	private String collectionName;
	private String query;
	private String projection;

	public MongoQueryWithProjectionExecutor(ResultStore store, List<Consumer<List<Record>>> script, Map<String, String> uuids, 
			List<Path> signature, String collectionName, String query,
			String projection, Map<String, Binding> bindings, String connectionString, String dbName) {
		super(store, script, uuids, bindings, signature);
		this.dbName = dbName;
		this.connectionString = connectionString;
		this.collectionName = collectionName;
		this.query = query;
		this.projection = projection;
	}

	@Override
	protected ResultIterator performSelect(Map<String, String> values) {
		MongoClient mongoClient = MongoClients.create(connectionString);
		MongoDatabase db = mongoClient.getDatabase(dbName);
		StringSubstitutor sub = new StringSubstitutor(values);
		String resolvedQuery = sub.replace(query);
		MongoCollection<Document> coll = db.getCollection(collectionName);
		Document pattern = Document.parse(resolvedQuery);
		return new MongoDBIterator(coll.find(pattern).projection(Document.parse(projection)));
	}

}
