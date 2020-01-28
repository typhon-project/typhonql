package nl.cwi.swat.typhonql.backend;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.IntStream;

import org.apache.commons.text.StringSubstitutor;
import org.bson.Document;

import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;

public class MongoDBEngine extends Engine {
	private String host;
	private int port;
	private String dbName;
	private String user;
	private String password;

	public MongoDBEngine(ResultStore store, String host, int port, String dbName, String user, String password) {
		super(store);
		this.host = host;
		this.port = port;
		this.dbName = dbName;
		this.user = user;
		this.password = password;
	}

	private ResultIterator performSelect(String query, Map<String, String> values) {
		String connString = getConnectionString(host, port, dbName, user, password);
		MongoClient mongoClient = MongoClients.create(connString);
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

	private String getConnectionString(String host, int port, String dbName, String user, String password) {
		return "mongodb://" + user + ":" + password + "@" + host + ":" + port;
	}

	@Override
	protected ResultIterator executeSelect(String resultId, String query, LinkedHashMap<String, Binding> bindings,
			Map<String, String> values) {
		if (values.size() == bindings.size()) {
			return performSelect(query, values); 
		}
		else {
			List<ResultIterator> lst = new ArrayList<>();
			String var = bindings.keySet().iterator().next();
			Binding binding = bindings.get(var);
			ResultIterator results =  store.getResults(binding.getReference());
			results.beforeFirst();
			while (results.hasNextResult()) {
				results.nextResult();
				String value = (binding.getAttribute().equals("@id"))? results.getCurrentId(binding.getType()) : (String) results.getCurrentField(binding.getType(), binding.getAttribute());
				values.put(var, value);
				lst.add(executeSelect(resultId, query, bindings, values));
			}
			return new AggregatedResultIterator(lst);
		}
	}

}
