package nl.cwi.swat.typhonql.workingset;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.stream.Collectors;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.annotation.JsonDeserialize;

import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.IInteger;
import io.usethesource.vallang.IList;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;

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
		else if (object instanceof IConstructor) {
			// TODO do the resolution for entities
			IConstructor con = (IConstructor) object;
			if (con.getName().equals("uuid")) {
				IString uuid = (IString) con.getChildren().iterator().next();
				return new EntityRef(uuid.getValue());
			}
			
		}
		
		throw new RuntimeException("Unknown conversion for Rascal value of type" + object.getClass());
	}
	
	

}
