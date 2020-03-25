package nl.cwi.swat.typhonql.client.resulttable;

import java.io.IOException;
import java.io.OutputStream;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.stream.Collectors;

import org.rascalmpl.values.ValueFactoryFactory;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.databind.ObjectMapper;

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
import nl.cwi.swat.typhonql.workingset.EntityRef;
import nl.cwi.swat.typhonql.workingset.JsonSerializableResult;


public class ResultTable implements JsonSerializableResult, IExternalValue {

	private static final ObjectMapper mapper;
	
	static {
		//mapper.configure(DeserializationFeature.
		mapper = new ObjectMapper().configure(JsonGenerator.Feature.AUTO_CLOSE_TARGET, false);
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

	public static ResultTable fromIValue(IValue v) {
		// map[str entity, list[Entity] entities];
		if (v instanceof ITuple) {
			ITuple tuple = (ITuple) v;
			IList columns = (IList) tuple.get(0);
			IList vs = (IList) tuple.get(1);
			
			Iterator<IValue> columnIter = columns.iterator();
			List<String> columnNames = new ArrayList<String>();
			while (columnIter.hasNext()) {
				IString c = (IString) columnIter.next();
				columnNames.add(c.getValue());
			}
			
			Iterator<IValue> rowsIter = vs.iterator();
			List<List<Object>> values = new ArrayList<>();
			while (rowsIter.hasNext()) {
				IList row = (IList) rowsIter.next();
				Iterator<IValue> oneRowIter = row.iterator();
				List<Object> objects = new ArrayList<>();
				while (oneRowIter.hasNext()) {
					IValue o = oneRowIter.next();
					objects.add(toJava(o)); 
				}
				values.add(objects);
			}
			
			return new ResultTable(columnNames, values);
		} else
			throw new RuntimeException("IValue does not represent a working set");

	}
	
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


	public void serializeJSON(OutputStream target) throws IOException {
		mapper.writeValue(target, this);
	}
	
	public void print() {
		System.out.println(String.join(", ", columnNames));
		for (List<Object> vs : values) {
			System.out.println(String.join(",", 
					vs.stream().map(o -> o.toString()).collect(Collectors.toList())));
		}
	}
	
	@Override
	@JsonIgnore
	public Type getType() {
		return TF.externalType(TF.valueType());
	}

}
