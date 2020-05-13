package nl.cwi.swat.typhonql.client.resulttable;

import java.io.IOException;
import java.io.OutputStream;
import java.math.BigInteger;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoField;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.Polygon;
import org.rascalmpl.values.ValueFactoryFactory;
import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializerProvider;
import com.fasterxml.jackson.databind.module.SimpleModule;
import com.fasterxml.jackson.databind.ser.std.StdSerializer;
import io.usethesource.vallang.IExternalValue;
import io.usethesource.vallang.IListWriter;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;


public class ResultTable implements JsonSerializableResult, IExternalValue {

	private static final ObjectMapper mapper;
	
	static {
		mapper = new ObjectMapper().configure(JsonGenerator.Feature.AUTO_CLOSE_TARGET, false);
		SimpleModule geomModule = new SimpleModule();
		geomModule.addSerializer(Geometry.class, new GeometrySerializer());
		geomModule.addSerializer(Polygon.class, new GeometrySerializer());
		geomModule.addSerializer(Point.class, new GeometrySerializer());
		mapper.registerModule(geomModule);
		mapper.canSerialize(EntityRef.class);

	}
				
	private List<String> columnNames;
	private List<List<Object>> values;
	
	public ResultTable(List<String> columnNames, List<List<Object>> values) {
		this.columnNames = columnNames;
		this.values = values;
	}
	
	public ResultTable() {
		this(new ArrayList<>(), new ArrayList<>());
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
	public ITuple toIValue() {
		IValueFactory vf = ValueFactoryFactory.getValueFactory();
		IListWriter cnw = vf.listWriter();
		for (String cn: columnNames)
			cnw.append(vf.string(cn));
		IListWriter vsw = vf.listWriter();
		
		for (List<Object> row : values) {
			IListWriter osw = vf.listWriter();
			for (Object o : row) {
				osw.append(toIValue(vf, o));
			}
			vsw.append(osw.done());
		}
				
		return vf.tuple(cnw.done(), vsw.done());
		
	}
	
	@JsonIgnore
	public static IValue toIValue(IValueFactory vf, Object v) {
		if (v == null) {
			return vf.tuple(vf.bool(false), vf.string(""));
		}
		
		if (v instanceof Integer) {
			return vf.integer((Integer) v);
		}
		else if (v instanceof String) {
			return vf.string((String) v);
		}
		else if (v instanceof LocalDate) {
			LocalDate ld = (LocalDate) v;
			return vf.date(ld.getYear(), ld.getMonthValue(), ld.getDayOfMonth());
		}
		else if (v instanceof LocalDateTime) {
			LocalDateTime ld = (LocalDateTime) v;
			return vf.datetime(ld.getYear(), ld.getMonthValue(), ld.getDayOfMonth(), ld.getHour(), ld.getMinute(), ld.getSecond(), ld.get(ChronoField.MILLI_OF_SECOND));
		}
		else if (v instanceof List) {
			IListWriter lw = vf.listWriter();
			List<Object> os = (List<Object>) v;
			lw.appendAll(os.stream().map(o -> toIValue(vf, o)).collect(Collectors.toList()));
			return lw.done();
		}
		else if (v instanceof EntityRef) {
			return vf.tuple(vf.bool(true), vf.string(((EntityRef) v).getUuid()));
		}
		else if (v instanceof Geometry) {
			return vf.string(((Geometry) v).toText());
		}
		throw new RuntimeException("Unknown conversion for Java type " + v.getClass());
	}

	@JsonIgnore
	public void serializeJSON(OutputStream target) throws IOException {
		mapper.writeValue(target, this);
	}
	
	@Override
	public String toString() {
		StringBuilder result = new StringBuilder();
		result.append("ResultTable { \n");
		result.append("\tcolumns: \n");
		boolean first = true;
		for (String c : columnNames) {
			if (first) {
				first = false;
				result.append('\t');
				result.append('\t');
			}
			else {
				result.append(',');
			}
			result.append(c);
		}
		result.append("\n\trows: \n");
		for (List<Object> r : values) {
            result.append('\t');
            result.append('\t');
            result.append('[');
            first = true;
            for (Object o : r) {
            	if (first) {
            		first = false;
            	}
            	else {
            		result.append(',');
            	}
            	result.append(o.toString());
            }
            result.append(']');
		}
		return result.toString();
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

}
