package nl.cwi.swat.typhonql.backend.cassandra;

import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.UUID;
import java.util.function.Consumer;
import java.util.function.Supplier;
import java.util.regex.Matcher;
import java.util.stream.Collectors;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.io.WKTWriter;
import com.datastax.oss.driver.api.core.CqlSession;
import com.datastax.oss.driver.api.core.cql.SimpleStatement;
import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.Engine;
import nl.cwi.swat.typhonql.backend.QueryExecutor;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultIterator;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.UpdateExecutor;
import nl.cwi.swat.typhonql.backend.rascal.Path;

public class CassandraEngine extends Engine {

	public CassandraEngine(ResultStore store, List<Consumer<List<Record>>> script, List<Runnable> updates, Map<String, String> uuids) {
		super(store, script, updates, uuids);
	}

	public void executeSelect(String resultId, String query, Map<String, Binding> bindings, List<Path> signature, Supplier<CqlSession> connection) {
		new QueryExecutor(store, script, uuids, bindings, signature) {
			@Override
			protected ResultIterator performSelect(Map<String, Object> values) {
				return new CassandraIterator(connection.get().execute(compileQuery(query, values)));
			}
		}.executeSelect(resultId);
	}
	

	
	public void executeUpdate(String query, Map<String, Binding> bindings, Supplier<CqlSession> connection) {
		new UpdateExecutor(store, updates, uuids, bindings) {
			@Override
			protected void performUpdate(Map<String, Object> values) {
				connection.get().execute(compileQuery(query, values));
			}
		}.executeUpdate();
	}

    private SimpleStatement compileQuery(String query, Map<String, Object> values) {
    	// replace QL placeholders with cassandra placeholders
		Matcher m = QL_PARAMS.matcher(query);
		StringBuffer replacedQuery = new StringBuffer();
		while (m.find()) {
			m.appendReplacement(replacedQuery, ":" + m.group(1));
		}
		m.appendTail(replacedQuery);
    	return SimpleStatement.newInstance(replacedQuery.toString(), encode(values)).setTimeout(Duration.ofSeconds(30));
    }
	
	private Map<String, Object> encode(Map<String, Object> values) {
		return values.entrySet().stream()
				.collect(Collectors.toMap(
						Entry::getKey, 
						e -> encode(e.getValue())
					)
				);
	}

	private Object encode(Object value) {
		if (value instanceof Geometry) {
			return new WKTWriter().write((Geometry) value);
		}
		if (value instanceof String) {
			String str = (String)value;
			if (str.length() == 36 && str.charAt(8) == '-') {
				// chance that is an uuid, so let's try
				try {
					return UUID.fromString(str);
				}
				catch (IllegalArgumentException e) {
					// it was not a UUID
					return str;
				}
			}
			return str;
		}
		// other java values are just fine as they are
		return value;
	}
}
