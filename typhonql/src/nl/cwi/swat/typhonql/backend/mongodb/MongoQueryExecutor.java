package nl.cwi.swat.typhonql.backend.mongodb;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.function.Consumer;
import java.util.stream.Collectors;
import org.apache.commons.text.StringSubstitutor;
import org.bson.Document;
import org.locationtech.jts.geom.Geometry;
import org.wololo.jts2geojson.GeoJSONWriter;
import com.mongodb.client.FindIterable;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;
import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.QueryExecutor;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultIterator;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.rascal.Path;

public class MongoQueryExecutor extends QueryExecutor {

	private final String collectionName;
	private final String query;
	private final MongoDatabase db;

	public MongoQueryExecutor(ResultStore store, List<Consumer<List<Record>>> script, Map<String, String> uuids,
			List<Path> signature, String collectionName, String query, Map<String, Binding> bindings,
			MongoDatabase db) {
		super(store, script, uuids, bindings, signature);
		this.db = db;
		this.collectionName = collectionName;
		this.query = query;
	}
	
	protected FindIterable<Document> buildFind(Map<String, Object> values) {
		StringSubstitutor sub = new StringSubstitutor(serialize(values));
		String resolvedQuery = sub.replace(query);
		MongoCollection<Document> coll = db.getCollection(collectionName);
		Document pattern = Document.parse(resolvedQuery);
		return coll.find(pattern);
	}
	

	@Override
	protected ResultIterator performSelect(Map<String, Object> values) {
		return new MongoDBIterator(buildFind(values));
	}

	protected Map<String,String> serialize(Map<String, Object> values) {
		return values.entrySet().stream()
				.collect(Collectors.toMap(
						Entry::getKey, 
						e -> serialize(e.getValue())
					)
				);

	}

	private String serialize(Object obj) {
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

}
