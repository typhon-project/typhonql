package nl.cwi.swat.typhonql.backend;

import org.bson.Document;

import com.mongodb.client.MongoCursor;
import com.mongodb.client.MongoIterable;

public class MongoDBIterator implements ResultIterator {

	private String type;
	private MongoIterable<Document> results;
	private MongoCursor<Document> cursor = null;
	private Document current = null;

	public MongoDBIterator(String type, MongoIterable<Document> results) {
		this.type = type;
		this.results = results;
		this.cursor = results.cursor();
	}

	@Override
	public void nextResult() {
		this.current = cursor.next();
	}

	@Override
	public boolean hasNextResult() {
		return cursor.hasNext();
	}

	@Override
	public String getCurrentId() {
		return current.getString("_id");
	}

	@Override
	public Object getCurrentField(String name) {
		return current.get(name);
	}

	@Override
	public void beforeFirst() {
		cursor = results.cursor();
	}

	@Override
	public String getType() {
		return type;
	}

}
