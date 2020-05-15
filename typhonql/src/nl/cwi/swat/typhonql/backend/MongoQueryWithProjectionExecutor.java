package nl.cwi.swat.typhonql.backend;

import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import org.bson.Document;
import com.mongodb.client.MongoDatabase;
import nl.cwi.swat.typhonql.backend.rascal.Path;

public class MongoQueryWithProjectionExecutor extends MongoQueryExecutor {

	private final String projection;

	public MongoQueryWithProjectionExecutor(ResultStore store, List<Consumer<List<Record>>> script, Map<String, String> uuids,
			List<Path> signature, String collectionName, String query, 
			String projection, Map<String, Binding> bindings, MongoDatabase db) {
		super(store, script, uuids, signature, collectionName, query, bindings, db);
		this.projection = projection;
	}

	@Override
	protected ResultIterator performSelect(Map<String, Object> values) {
		return new MongoDBIterator(buildFind(values).projection(Document.parse(projection)));
	}

}
