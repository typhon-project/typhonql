package nl.cwi.swat.typhonql.backend;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.IntStream;

import org.apache.commons.text.StringSubstitutor;
import org.bson.Document;

import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;

public class MongoQueryExecutor extends QueryExecutor {


	private String connectionString;
	private String dbName;

	public MongoQueryExecutor(ResultStore store, String query,
			LinkedHashMap<String, Binding> bindings, String connectionString, String dbName) {
		super(store, query, bindings);
		this.dbName = dbName;
		this.connectionString = connectionString;
		
	}

	@Override
	protected ResultIterator performSelect(Map<String, String> values) {
		MongoClient mongoClient = MongoClients.create(connectionString);
		MongoDatabase db = mongoClient.getDatabase(dbName);
		StringSubstitutor sub = new StringSubstitutor(values);
		String resolvedQuery = sub.replace(query);

		String[] strings = resolvedQuery.split("\n");
		String collectionName = strings[0];
		String json = String.join("\n", 
				IntStream.range(1, strings.length).mapToObj(i -> strings[i]).toArray(String[]::new));
		MongoCollection<Document> coll = db.getCollection(collectionName);
		Document pattern = Document.parse(json);
		return new MongoDBIterator(coll.find(pattern));
	}

}
