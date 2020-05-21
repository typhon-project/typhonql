package nl.cwi.swat.typhonql.backend.mongodb;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.function.BiConsumer;
import java.util.function.Consumer;
import java.util.stream.Collectors;
import org.apache.commons.text.StringSubstitutor;
import org.bson.Document;
import org.locationtech.jts.geom.Geometry;
import org.wololo.jts2geojson.GeoJSONWriter;
import com.mongodb.BasicDBObject;
import com.mongodb.MongoNamespace;
import com.mongodb.client.FindIterable;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;
import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.Engine;
import nl.cwi.swat.typhonql.backend.QueryExecutor;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultIterator;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.UpdateExecutor;
import nl.cwi.swat.typhonql.backend.rascal.Path;

public class MongoDBEngine extends Engine {
	private final MongoDatabase db;

	public MongoDBEngine(ResultStore store, List<Consumer<List<Record>>> script, List<Runnable> updates, Map<String, String> uuids,
			MongoDatabase db) {
		super(store, script, updates, uuids);
		this.db = db;
	}

	public void executeFind(String resultId, String collectionName, String query, Map<String, Binding> bindings, List<Path> signature) {
		new QueryExecutor(store, script, uuids, bindings, signature) {
			@Override
			protected ResultIterator performSelect(Map<String, Object> values) {
				return new MongoDBIterator(buildFind(collectionName, query, values));
			}
		}.executeSelect(resultId);
	}

	public void executeFindWithProjection(String resultId, String collectionName, String query, String projection,
			Map<String, Binding> bindings, List<Path> signature) {
		new QueryExecutor(store, script, uuids, bindings, signature) {
			@Override
			protected ResultIterator performSelect(Map<String, Object> values) {
				return new MongoDBIterator(buildFind(collectionName, query, values).projection(Document.parse(projection)));
			}
		}.executeSelect(resultId);
	}

	private FindIterable<Document> buildFind(String collectionName, String query, Map<String, Object> values) {
		StringSubstitutor sub = new StringSubstitutor(serialize(values));
		String resolvedQuery = sub.replace(query);
		MongoCollection<Document> coll = db.getCollection(collectionName);
		Document pattern = Document.parse(resolvedQuery);
		return coll.find(pattern);
	}

	private static Map<String,String> serialize(Map<String, Object> values) {
		return values.entrySet().stream()
				.collect(Collectors.toMap(
						Entry::getKey, 
						e -> serialize(e.getValue())
					)
				);
	}

	private static String serialize(Object obj) {
		if (obj == null) {
			return "null";
		}
		if (obj instanceof Integer || obj instanceof Boolean || obj instanceof Double) {
			return String.valueOf(obj);
		}
		else if (obj instanceof String) {
			return "\"" + (String) obj + "\"";
		}
		else if (obj instanceof Geometry) {
			return new GeoJSONWriter().write((Geometry)obj).toString();
		}
		else if (obj instanceof LocalDate) {
			return serialize(((LocalDate) obj).atStartOfDay());
		}
		else if (obj instanceof LocalDateTime) {
			return "{\"$date\": {\"$numberLong\":" + ((LocalDateTime)obj).toEpochSecond(ZoneOffset.UTC) * 1000L + "}}";
		}
		else
			throw new RuntimeException("Query executor does not know how to serialize object of type " +obj.getClass());
	}

	protected static Document resolveQuery(String query, Map<String, Object> values) {
		return Document.parse(new StringSubstitutor(serialize(values)).replace(query));
	}
	
	private void executeUpdate(String collectionName, String doc, Map<String, Binding> bindings, BiConsumer<MongoCollection<Document>, Document> operation) {
		new UpdateExecutor(store, updates, uuids, bindings) {
			
			@Override
			protected void performUpdate(Map<String, Object> values) {
				MongoCollection<Document> coll = db.getCollection(collectionName);
				Document parsedQuery = resolveQuery(doc, values);
				operation.accept(coll, parsedQuery);
			}
		}.executeUpdate();
	}

    @FunctionalInterface
    private interface TriConsumer<T, U, V> {

        void accept(T t, U u, V v);

    }
	private void executeFilteredUpdate(String collectionName, String filter, String doc, Map<String, Binding> bindings, TriConsumer<MongoCollection<Document>, Document, Document> operation) {
		new UpdateExecutor(store, updates, uuids, bindings) {
			
			@Override
			protected void performUpdate(Map<String, Object> values) {
				MongoCollection<Document> coll = db.getCollection(collectionName);
				Document parsedFilter = resolveQuery(filter, values);
				Document parsedQuery = resolveQuery(doc, values);
				operation.accept(coll, parsedFilter, parsedQuery);
			}
		}.executeUpdate();
	}

	public void executeInsertOne(String dbName, String collectionName, String doc, Map<String, Binding> bindings) {
		executeUpdate(collectionName, doc, bindings, MongoCollection<Document>::insertOne);
	}
	
	public void executeFindAndUpdateOne(String dbName, String collectionName, String query, String update, Map<String, Binding> bindings) {
		executeFilteredUpdate(collectionName, query, update, bindings, MongoCollection<Document>::findOneAndUpdate);
	}
	
	public void executeFindAndUpdateMany(String dbName, String collectionName, String query, String update, Map<String, Binding> bindings) {
		executeFilteredUpdate(collectionName, query, update, bindings, MongoCollection<Document>::updateMany);
	}
	
	public void executeDeleteOne(String dbName, String collectionName, String query, Map<String, Binding> bindings) {
		executeUpdate(collectionName, query, bindings, MongoCollection<Document>::deleteOne);
	}
	
	public void executeDeleteMany(String dbName, String collectionName, String query, Map<String, Binding> bindings) {
		executeUpdate(collectionName, query, bindings, MongoCollection<Document>::deleteMany);
	}
	
	public void executeCreateCollection(String dbName, String collectionName) {
		db.createCollection(collectionName);
	}
	
	public void executeDropCollection(String dbName, String collectionName) {
		db.getCollection(collectionName).drop();
	}

	public void executeDropDatabase(String dbName) {
		db.drop();
	}

	public void executeRenameCollection(String dbName, String collection, String newName) {
		db.getCollection(collection).renameCollection(new MongoNamespace(newName));
	}

	public void executeCreateIndex(String collectionName, String selector, String index) {
		db.getCollection(collectionName).createIndex(new BasicDBObject(selector, index));
	}


}
