package nl.cwi.swat.typhonql.client.resulttable;

import java.io.IOException;
import java.io.OutputStream;
import java.util.List;
import java.util.stream.Stream;

import nl.cwi.swat.typhonql.client.JsonSerializableResult;

public class StreamingResultTable implements JsonSerializableResult {

	private final List<String> columnNames;
	private final Stream<Object[]> values;

	public StreamingResultTable(List<String> columnNames, Stream<Object[]> values) {
		this.columnNames = columnNames;
		this.values = values;
	}
	
	public List<String> getColumnNames() {
		return columnNames;
	}
	
	public Stream<Object[]> getValues() {
		return values;
	}

	@Override
	public void serializeJSON(OutputStream target) throws IOException {
		QLSerialization.mapper.writeValue(target, this);
	}
}
