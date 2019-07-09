package nl.cwi.swat.typhonql;

import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.Map.Entry;

import lang.typhonql.util.MakeUUID;

public class Entity implements Iterable<Map.Entry<String,Object>> {
	
	private final Map<String, Object> fields;
	private final String id;
	private final String type;
	
	// todo: we need a Ref object to distinguish uuid strings from ordinary strings.
	
	public static Entity of(String type, Object ...keyVals) {
		Map<String, Object> map = new HashMap<>();
		for (int i = 0; i < keyVals.length; i++) {
			map.put((String)keyVals[i], keyVals[i+1]);
		}
		return new Entity(type, MakeUUID.randomUUID(), map);
	}

	public Entity(String type) {
		this(type, MakeUUID.randomUUID());
	}
	
	
	public Entity(String type, String id) {
		this(type, id, new HashMap<String, Object>());
	}
	
	public Entity(String type, String id, Map<String,Object> map) {
		this.type = type;
		this.id = id;
		this.fields = map;
	}
	
	public String getId() {
		return id;
	}
	
	public String getType() {
		return type;
	}
	
	public Object get(String field) {
		return fields.get(field);
	}
	
	public Object set(String field, Object value) {
		return fields.put(field, value);
	}
	

	@Override
	public Iterator<Entry<String, Object>> iterator() {
		return fields.entrySet().iterator();
	}


}
