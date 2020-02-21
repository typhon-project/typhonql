package nl.cwi.swat.typhonql.backend;

import java.util.Map;

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

	public MongoDBEngine(ResultStore store, Map<String, String> uuids, String host, int port, String dbName, String user, String password) {
		super(store, uuids);
		this.host = host;
		this.port = port;
		this.dbName = dbName;
		this.user = user;
		this.password = password;
	}
	
	private String getConnectionString() {
		return "mongodb://" + user + ":" + password + "@" + host + ":" + port;
	}

	public void executeFind(String resultId, String collectionName, String query, Map<String, Binding> bindings) {
		ResultIterator results = new MongoQueryExecutor(store, uuids, collectionName, query, bindings, getConnectionString(), dbName).executeSelect();
		storeResults(resultId, results);
	}

	public void executeFindWithProjection(String resultId, String collectionName, String query, String projection,
			Map<String, Binding> bindings) {
		ResultIterator results = new MongoQueryWithProjectionExecutor(store, uuids, collectionName, query, projection, bindings, getConnectionString(), dbName).executeSelect();
		storeResults(resultId, results);
		
	}

	public void executeInsertOne(String dbName, String collectionName, String doc, Map<String, Binding> bindings) {
		new MongoInsertOneExecutor(store, uuids, collectionName, doc, bindings, getConnectionString(), dbName).executeUpdate();
	}

	
	public void executeFindAndUpdateOne(String dbName, String collectionName, String query, String update, Map<String, Binding> bindings) {
		new MongoFindOneAndUpdateExecutor(store, uuids, collectionName, query, update, bindings, getConnectionString(), dbName).executeUpdate();
	}
	
	public void executeDeleteOne(String dbName, String collectionName, String query, Map<String, Binding> bindings) {
		new MongoUpdateExecutor(store, uuids, collectionName, query, bindings, getConnectionString(), dbName) {
			
			@Override
			protected void performUpdate(MongoCollection<Document> coll, Document resolveQuery) {
				coll.deleteOne(resolveQuery);
			}
		}.executeUpdate();
	}

}
