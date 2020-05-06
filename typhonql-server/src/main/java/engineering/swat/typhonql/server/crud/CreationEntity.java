package engineering.swat.typhonql.server.crud;

import java.util.Map;

public class CreationEntity {
	private Map<String, Object> fields;

	public CreationEntity(Map<String, Object> fields) {
		super();
		this.fields = fields;
	}
	
	public CreationEntity() {
		
	}

	public Map<String, Object> getFields() {
		return fields;
	}

	public void setFields(Map<String, Object> fields) {
		this.fields = fields;
	}
	
	
	
	
}
