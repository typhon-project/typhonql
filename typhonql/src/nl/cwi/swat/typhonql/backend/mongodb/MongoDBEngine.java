package nl.cwi.swat.typhonql.backend.mongodb;

import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

import org.bson.Document;
import com.mongodb.BasicDBObject;
import com.mongodb.MongoNamespace;
import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;
import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.Engine;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.rascal.Path;

public class MongoDBEngine extends Engine {
	MongoDatabase db;

	public MongoDBEngine(ResultStore store, List<Consumer<List<Record>>> script, List<Runnable> updates, Map<String, String> uuids,
			MongoDatabase db) {
		super(store, script, updates, uuids);
		this.db = db;
	}

	public void executeFind(String resultId, String collectionName, String query, Map<String, Binding> bindings, List<Path> signature) {
		new MongoQueryExecutor(store, script, uuids, signature, collectionName, query, bindings, db).executeSelect(resultId);
	}

	public void executeFindWithProjection(String resultId, String collectionName, String query, String projection,
			Map<String, Binding> bindings, List<Path> signature) {
		new MongoQueryWithProjectionExecutor(store, script, uuids, signature, collectionName, query, projection, bindings, db).executeSelect(resultId);
		
	}

	public void executeInsertOne(String dbName, String collectionName, String doc, Map<String, Binding> bindings) {
		new MongoInsertOneExecutor(store, updates, uuids, collectionName, doc, bindings, db).executeUpdate();
	}

	
	public void executeFindAndUpdateOne(String dbName, String collectionName, String query, String update, Map<String, Binding> bindings) {
		new MongoFindOneAndUpdateExecutor(store, updates, uuids, collectionName, query, update, bindings, db).executeUpdate();
	}
	
	public void executeFindAndUpdateMany(String dbName, String collectionName, String query, String update, Map<String, Binding> bindings) {
		new MongoFindManyAndUpdateExecutor(store, updates, uuids, collectionName, query, update, bindings, db).executeUpdate();
	}
	
	public void executeDeleteOne(String dbName, String collectionName, String query, Map<String, Binding> bindings) {
		new MongoUpdateExecutor(store, updates, uuids, collectionName, query, bindings, db) {
			
			@Override
			protected void performUpdate(MongoCollection<Document> coll, Document resolveQuery) {
				coll.deleteOne(resolveQuery);
			}
		}.executeUpdate();
	}
	
	public void executeDeleteMany(String dbName, String collectionName, String query, Map<String, Binding> bindings) {
		new MongoUpdateExecutor(store, updates, uuids, collectionName, query, bindings, db) {
			
			@Override
			protected void performUpdate(MongoCollection<Document> coll, Document resolveQuery) {
				coll.deleteMany(resolveQuery);
			}
		}.executeUpdate();
	}
	
	public void executeCreateCollection(String dbName, String collectionName) {
		db.createCollection(collectionName);
	}
	
	public void executeDropCollection(String dbName, String collectionName) {
		MongoCollection<Document> coll = db.getCollection(collectionName);
		coll.drop();
	}

	public void executeDropDatabase(String dbName) {
		db.drop();
	}

	public void executeRenameCollection(String dbName, String collection, String newName) {
		MongoCollection<Document> coll = db.getCollection(collection);
		coll.renameCollection(new MongoNamespace(newName));
	}

	public void executeCreateIndex(String collectionName, String selector, String index) {
		MongoCollection<Document> coll = db.getCollection(collectionName);
		coll.createIndex(new BasicDBObject(selector, index));
	}

}
