package nl.cwi.swat.typhonql.backend;

import java.util.stream.IntStream;

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

	@Override
	protected ResultIterator performSelect(String query) {
		String connString = getConnectionString(host, port, dbName, user, password);
		MongoClient mongoClient = MongoClients.create(connString);
		MongoDatabase db = mongoClient.getDatabase(dbName);
		String[] strings = query.split("\n");
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

}
