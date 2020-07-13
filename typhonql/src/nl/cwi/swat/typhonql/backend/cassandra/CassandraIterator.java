package nl.cwi.swat.typhonql.backend.cassandra;

import java.time.ZoneId;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.UUID;
import java.util.function.BiFunction;
import java.util.function.Function;
import com.datastax.oss.driver.api.core.cql.ColumnDefinition;
import com.datastax.oss.driver.api.core.cql.ColumnDefinitions;
import com.datastax.oss.driver.api.core.cql.ResultSet;
import com.datastax.oss.driver.api.core.cql.Row;
import com.datastax.oss.driver.api.core.type.DataTypes;
import nl.cwi.swat.typhonql.backend.ResultIterator;

public class CassandraIterator implements ResultIterator {

	private final ResultSet results;
	private Iterator<Row> it;
	private Row current;
	private Map<String, Function<Row, Object>> columnMap;
	private static final Map<Integer, BiFunction<Row, Integer, Object>> mappers;
	
	static {
		mappers = new HashMap<Integer, BiFunction<Row,Integer,Object>>();
		mappers.put(DataTypes.BOOLEAN.getProtocolCode(), Row::getBoolean);
		mappers.put(DataTypes.DATE.getProtocolCode(), Row::getLocalDate);
		mappers.put(DataTypes.DOUBLE.getProtocolCode(), Row::getDouble);
		mappers.put(DataTypes.INT.getProtocolCode(), Row::getInt);
		mappers.put(DataTypes.TEXT.getProtocolCode(), Row::getString);
		mappers.put(DataTypes.TIME.getProtocolCode(), Row::getLocalTime);
		mappers.put(DataTypes.TIMESTAMP.getProtocolCode(), (r, c) -> r.getInstant(c).atZone(ZoneId.of("UTC")).toLocalDateTime());
		mappers.put(DataTypes.UUID.getProtocolCode(), (r, c) -> r.getUuid(c).toString());
	}

	public CassandraIterator(ResultSet results) {
		this.results = results;
		this.it = results.iterator();
		this.columnMap = prepare(results.getColumnDefinitions());
	}

	private Map<String, Function<Row, Object>> prepare(ColumnDefinitions cols) {
		Map<String, Function<Row, Object>> result = new HashMap<>();
		for (int i = 0; i < cols.size(); i++) {
			int c = i;
			ColumnDefinition col = cols.get(c);
			BiFunction<Row, Integer, Object> mapper = mappers.get(col.getType().getProtocolCode());
			if (mapper == null) {
				throw new RuntimeException("Unknown column type: " + col.getType());
			}
			result.put(col.getName().asInternal(), (r) -> mapper.apply(r, c));
		}
		return result;
	}

	@Override
	public void nextResult() {
		current = it.next();
	}

	@Override
	public boolean hasNextResult() {
		return it.hasNext();
	}

	@Override
	public UUID getCurrentId(String label, String type) {
		return UUID.fromString(current.getString(columnName(label, type, "@id")));
	}

	@Override
	public Object getCurrentField(String label, String type, String name) {
		 Function<Row, Object> getter = columnMap.get(columnName(label, type, name));
		 if (getter == null) {
			 throw new RuntimeException("Column: " + columnName(label, type, name) + " not in column definitions: " + columnMap.keySet());
		 }
		 return getter.apply(current);
	}

	private static String columnName(String label, String type, String name) {
		return label + "." + type + "." + name;
	}

	@Override
	public void beforeFirst() {
		it = this.results.iterator();
	}

}
