package nl.cwi.swat.typhonql.workingset;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.stream.Collectors;

import org.rascalmpl.values.ValueFactoryFactory;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.annotation.JsonDeserialize;

import io.usethesource.vallang.IBool;
import io.usethesource.vallang.IInteger;
import io.usethesource.vallang.IList;
import io.usethesource.vallang.IListWriter;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IMapWriter;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;

public class Entity {
	
	public String name;
	public String uuid;
	
	//@JsonDeserialize(contentUsing = FieldValueDeserializer.class)
	@JsonDeserialize(contentConverter = EntityRefConverter.class)
	public Map<String, Object> fields;
	
	public Entity(String name, String uuid) {
		this(name, uuid, new HashMap<>());
	}

	public Entity(String name, String uuid, Map<String, Object> fields) {
		super();
		this.name = name;
		this.uuid = uuid;
		this.fields = fields;
	}
	
	public Entity() {
		super();
	}
	
	@JsonProperty("type")
	public String getName() {
		return name;
	}

	public String getUuid() {
		return uuid;
	}

	public Map<String, Object> getFields() {
		return fields;
	}

	@Override
	public String toString() {
		return "Entity " + name + "{ uuid: " + uuid +", fields: ["
				+ String.join(", ", fields.entrySet().stream().map(e -> e.getKey() + ":" + e.getValue())
						.collect(Collectors.toList()))
				+ "] }";
	}

	public static Entity fromIValue(IValue v) {
		System.out.println(v);
		if (v instanceof ITuple) {
			ITuple tuple = (ITuple) v;
			IString name = (IString) tuple.get(0);
			IString uuid = (IString) tuple.get(1);
			Map<String, Object> fields = new HashMap<String, Object>();
			IMap map = (IMap) tuple.get(2);
			Iterator<Entry<IValue, IValue>> iter = map.entryIterator();
			while (iter.hasNext()) {
				Entry<IValue, IValue> entry = iter.next();
				IString key = (IString) entry.getKey();
				IValue object =  entry.getValue();
				try {
					Object javaObject = toJava(object);
					fields.put(key.getValue(), javaObject);
				} catch (RuntimeException e) {
					
				}
			}
			return new Entity(name.getValue(), uuid.getValue(), fields);
		}
		else
			throw new RuntimeException("IValue does not represent an entity");
	}
	
	public ITuple toIValue() {
		IValueFactory vf = ValueFactoryFactory.getValueFactory();
		IMapWriter mw = vf.mapWriter();
		for (Entry<String, Object> entry : fields.entrySet()) {
			String name = entry.getKey();
			Object v = entry.getValue();
			IValue iv = toIValue(vf, v);
			mw.put(vf.string(name), iv);
		}
		return vf.tuple(vf.string(this.name), vf.string(this.uuid), mw.done());
	}

	private static IValue toIValue(IValueFactory vf, Object v) {
		if (v == null) {
			return vf.tuple(vf.bool(false), vf.string(""));
		}
		
		if (v instanceof Integer) {
			return vf.integer((Integer) v);
		}
		else if (v instanceof String) {
			return vf.string((String) v);
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

	private static Object toJava(IValue object) {
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
	
	

}
