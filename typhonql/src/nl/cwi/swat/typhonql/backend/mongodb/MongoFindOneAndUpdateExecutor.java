package nl.cwi.swat.typhonql.backend.mongodb;

import java.util.List;
import java.util.Map;

import org.apache.commons.text.StringSubstitutor;
import org.bson.Document;

import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;
import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.ResultStore;

public class MongoFindOneAndUpdateExecutor extends MongoUpdateExecutor {

	private String update;

	public MongoFindOneAndUpdateExecutor(ResultStore store, List<Runnable> updates, Map<String, String> uuids, String collectionName,
			String query, String update, Map<String, Binding> bindings, MongoDatabase db) {
		super(store, updates, uuids, collectionName, query, bindings, db);
		this.update = update;
	}

	@Override
	protected void performUpdate(MongoCollection<Document> coll, Document filter, Document update) {
		coll.findOneAndUpdate(filter, update);
	}
	
	@Override
	protected void performUpdate(Map<String, String> values) {
		MongoCollection<Document> coll = db.getCollection(collectionName);
		performUpdate(coll, resolveQuery(values), resolveUpdate(values));
	}

	protected Document resolveUpdate(Map<String, String> values) {
		StringSubstitutor sub = new StringSubstitutor(values);
		//String resolvedQuery = "{$set: " + sub.replace(update) + "}";
		Document pattern = Document.parse(sub.replace(update));
		return pattern;
	}

	
	@Override
	protected void performUpdate(MongoCollection<Document> coll, Document resolveQuery) {
		throw new AssertionError("cannot call performUpdate without update");
	}

}
