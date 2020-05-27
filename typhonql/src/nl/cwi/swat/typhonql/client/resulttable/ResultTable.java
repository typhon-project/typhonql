package nl.cwi.swat.typhonql.client.resulttable;

import java.io.IOException;
import java.io.OutputStream;
import java.math.BigInteger;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Collections;
import java.util.List;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.Polygon;
import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializerProvider;
import com.fasterxml.jackson.databind.module.SimpleModule;
import com.fasterxml.jackson.databind.ser.std.StdSerializer;
import io.usethesource.vallang.IExternalValue;
import io.usethesource.vallang.type.Type;


public class ResultTable implements JsonSerializableResult, IExternalValue {


	private static final ObjectMapper mapper;
	
	static {
		SimpleModule customSerializers = new SimpleModule();
		customSerializers.addSerializer(Geometry.class, new GeometrySerializer());
		customSerializers.addSerializer(Polygon.class, new GeometrySerializer());
		customSerializers.addSerializer(Point.class, new GeometrySerializer());
		customSerializers.addSerializer(LocalDate.class, new LocalDateSerializer());
		customSerializers.addSerializer(LocalDateTime.class, new LocalDateTimeSerializer());

		mapper = new ObjectMapper().configure(JsonGenerator.Feature.AUTO_CLOSE_TARGET, false);
		mapper.registerModule(customSerializers);
	}
				
	private final List<String> columnNames;
	private final List<List<Object>> values;
	
	public ResultTable(List<String> columnNames, List<List<Object>> values) {
		this.columnNames = columnNames;
		this.values = values;
	}
	
	public ResultTable() {
		this(Collections.emptyList(), Collections.emptyList());
	}

	public List<String> getColumnNames() {
		return columnNames;
	}

	public List<List<Object>> getValues() {
		return values;
	}
	
	@JsonIgnore
	public boolean isEmpty() {
		return values == null || values.size() == 0;
	}
	
	@JsonIgnore
	public void serializeJSON(OutputStream target) throws IOException {
		mapper.writeValue(target, this);
	}
	
	
	
	@Override
	public String toString() {
		return "ResultTable [\ncolumnNames=" + columnNames + ",\n values=" + values + "\n]";
	}
	
	@Override
	@JsonIgnore
	public Type getType() {
		return TF.externalType(TF.valueType());
	}
	
	@Override
	@JsonIgnore
	public boolean isAnnotatable() {
        return false;
    }

	public static String serializeAsString(Object object) {
		// TODO complete all the cases
		if (object == null)
			return "null";
		if (object instanceof String)
			return "\"" + object + "\"";
		else if (object instanceof Integer || object instanceof BigInteger)
			return object.toString();
		else
			return object.toString();
		
	}
	
	@SuppressWarnings("serial")
	private static class GeometrySerializer extends StdSerializer<Geometry> {
		public GeometrySerializer() {
			super(Geometry.class);
		}

		@Override
		public void serialize(Geometry value, JsonGenerator gen, SerializerProvider provider)
				throws IOException {
			gen.writeString(value.toText());
		}
		
	}

	@SuppressWarnings("serial")
	public static class LocalDateSerializer extends StdSerializer<LocalDate> {
		
		public LocalDateSerializer() {
			super(LocalDate.class);
		}

		@Override
		public void serialize(LocalDate value, JsonGenerator gen, SerializerProvider provider)
				throws IOException {
			gen.writeString(value.format(DateTimeFormatter.ISO_LOCAL_DATE));
		}
	}
	
	
	@SuppressWarnings("serial")
	public static class LocalDateTimeSerializer extends StdSerializer<LocalDateTime> {
		
		public LocalDateTimeSerializer() {
			super(LocalDateTime.class);
		}

		@Override
		public void serialize(LocalDateTime value, JsonGenerator gen, SerializerProvider provider)
				throws IOException {
			gen.writeString(value.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
		}
	}

}
