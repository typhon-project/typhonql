package engineering.swat.typhonql.server.crud;

import java.util.Map;

public class EntityFields {
	private Map<String, Object> fields;

	public EntityFields(Map<String, Object> fields) {
		super();
		this.fields = fields;
	}
	
	public EntityFields() {
		
	}

	public Map<String, Object> getFields() {
		return fields;
	}

	public void setFields(Map<String, Object> fields) {
		this.fields = fields;
	}
	
	
	
	
}
