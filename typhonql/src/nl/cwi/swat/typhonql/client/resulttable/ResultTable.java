package nl.cwi.swat.typhonql.client.resulttable;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.stream.Collectors;

import org.rascalmpl.values.ValueFactoryFactory;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.databind.JavaType;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.annotation.JsonDeserialize;

import io.usethesource.vallang.IBool;
import io.usethesource.vallang.IExternalValue;
import io.usethesource.vallang.IInteger;
import io.usethesource.vallang.IList;
import io.usethesource.vallang.IListWriter;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;


public class ResultTable implements JsonSerializableResult, IExternalValue {

	private static final ObjectMapper mapper;
	
	static {
		//mapper.configure(DeserializationFeature.
		mapper = new ObjectMapper().configure(JsonGenerator.Feature.AUTO_CLOSE_TARGET, false);
		mapper.canDeserialize(mapper.getTypeFactory().constructSimpleType(EntityRef.class, new JavaType[0]));
		mapper.canSerialize(EntityRef.class);

	}
				
	private List<String> columnNames;
	private List<List<String>> values;
	
	public ResultTable(List<String> columnNames, List<List<String>> values) {
		this.columnNames = columnNames;
		this.values = values;
	}
	
	public ResultTable() {
		this(new ArrayList<>(), new ArrayList<>());
	}

	public List<String> getColumnNames() {
		return columnNames;
	}

	public List<List<String>> getValues() {
		return values;
	}
	
	@JsonIgnore
	public boolean isEmpty() {
		return values == null || values.size() == 0;
	}

	@JsonIgnore
	public static Object toJava(IValue object) {
		if (object instanceof IInteger) {
			return ((IInteger) object).intValue();
		}
		
		else if (object instanceof IString) {
			return ((IString) object).getValue();
		}
		else if (object instanceof IList) {
			Iterator<IValue> iter = ((IList) object).iterator();
			List<Object> lst = new ArrayList<Object>();
			while (iter.hasNext()) {
				IValue v = iter.next();
				lst.add(toJava(v));
			}
			return lst;
		}
		else if (object instanceof ITuple) {
			// TODO do the resolution for entities
			ITuple tuple = (ITuple) object;
			IBool isNotNull = (IBool) tuple.get(0);
			if (isNotNull.getValue()) {
				IString uuid = (IString) tuple.get(1);
				return new EntityRef(uuid.getValue());
			} else {
				return null;
			}
			
		}
		
		throw new RuntimeException("Unknown conversion for Rascal value of type " + object.getClass());
	}
	
	@JsonIgnore
	public ITuple toIValue() {
		IValueFactory vf = ValueFactoryFactory.getValueFactory();
		IListWriter cnw = vf.listWriter();
		for (String cn: columnNames)
			cnw.append(vf.string(cn));
		IListWriter vsw = vf.listWriter();
		
		for (List<String> row : values) {
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
		else if (v instanceof Timestamp) {
			return vf.datetime(((Timestamp) v).getTime());
		}
		else if (v instanceof java.sql.Date) {
			return vf.datetime(((java.sql.Date)v).getTime());
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
		throw new RuntimeException("Unknown conversion for Java type " + v.getClass());
	}

	@JsonIgnore
	public void serializeJSON(OutputStream target) throws IOException {
		mapper.writeValue(target, this);
	}
	
	@JsonIgnore
	public void print() {
		System.out.println(String.join(", ", columnNames));
		for (List<String> vs : values) {
			System.out.println(String.join(",", 
					vs.stream().map(o -> o.toString()).collect(Collectors.toList())));
		}
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

	@JsonIgnore
	public static ResultTable fromJSON(InputStream is) throws IOException {
		ResultTable rt = mapper.readValue(is, ResultTable.class);
		return rt;
	}

	public static String serialize(String type, String s) {
		// TODO complete all the cases
		if (type.equals("str") || type.equals("string"))
			return "\"" + s + "\"";
		else if (type.equals("int") || type.equals("integer"))
			return s;
		return s;
	}

}
