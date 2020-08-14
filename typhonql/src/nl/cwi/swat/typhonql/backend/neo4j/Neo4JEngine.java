package nl.cwi.swat.typhonql.backend.neo4j;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Map.Entry;
import java.util.UUID;
import java.util.function.Consumer;
import java.util.stream.Collectors;

import org.locationtech.jts.geom.Geometry;
import org.neo4j.driver.Driver;
import org.neo4j.driver.Session;
import org.wololo.jts2geojson.GeoJSONWriter;

import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.Engine;
import nl.cwi.swat.typhonql.backend.MultipleBindings;
import nl.cwi.swat.typhonql.backend.QueryExecutor;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultIterator;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.UpdateExecutor;
import nl.cwi.swat.typhonql.backend.rascal.Path;


public class Neo4JEngine extends Engine {
	private final Driver driver;

	public Neo4JEngine(ResultStore store, List<Consumer<List<Record>>> script, List<Runnable> updates, Map<String, List<UUID>> uuids,
			Driver driver) {
		super(store, script, updates, uuids);
		this.driver = driver;
	}
	
	public void executeUpdate(String query, Map<String, Binding> bindings, Optional<MultipleBindings> mBindings) {
		new UpdateExecutor(query, store, updates, uuids, bindings, mBindings) {
			@Override
			protected void performUpdate(Map<String, Object> values) {
				Map<String, Object> pars = toNeo4JObjects(values);
				try (Session session = driver.session()) {
					session.run(query, pars);
				}
			}
			
		}.executeUpdate();
	}

	public void executeMatch(String resultId, String query, Map<String, Binding> bindings, List<Path> signature) {
		new QueryExecutor(store, script, uuids, bindings, signature) {
			@Override
			protected ResultIterator performSelect(Map<String, Object> values) {
				Map<String, Object> pars = toNeo4JObjects(values);
				try (Session session = driver.session()) {
					return new Neo4JIterator(session.run(query, pars).list());
				}
			}
		}.executeSelect(resultId);
	}

	private static Map<String,Object> toNeo4JObjects(Map<String, Object> values) {
		return values.entrySet().stream()
				.collect(Collectors.toMap(
						Entry::getKey, 
						e -> toNeo4JObject(e.getValue())
					)
				);
	}

	private static Object toNeo4JObject(Object obj) {
		if (obj == null) {
			return null;
		}
		if (obj instanceof Integer || obj instanceof Boolean || obj instanceof Double| obj instanceof String) {
			return String.valueOf(obj);
		}
		else if (obj instanceof UUID) {
			return ((UUID) obj).toString();
		}
		if (obj instanceof Geometry) {
			return new GeoJSONWriter().write((Geometry)obj).toString();
		}
		else if (obj instanceof LocalDate) {
			return toNeo4JObject(((LocalDate) obj).atStartOfDay());
		}
		else if (obj instanceof LocalDateTime) {
			return "{\"$date\": {\"$numberLong\":" + ((LocalDateTime)obj).toEpochSecond(ZoneOffset.UTC) * 1000L + "}}";
		}
		else
			throw new RuntimeException("Query executor does not know how to serialize object of type " +obj.getClass());
	}
}
