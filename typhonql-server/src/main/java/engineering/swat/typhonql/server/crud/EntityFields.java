package engineering.swat.typhonql.server.crud;

import java.util.HashMap;
import java.util.Map;

public class EntityFields {
	private final Map<String, Object> fields;

	public EntityFields(Map<String, Object> fields) {
		this.fields = fields;
	}
	
	public EntityFields() {
		this(new HashMap<>());
	}

	public Map<String, Object> getFields() {
		return fields;
	}
	
}
