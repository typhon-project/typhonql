package nl.cwi.swat.typhonql.backend;

import java.util.HashMap;
import java.util.Map;

public class EntityModel {
	private String entityName;
	private Map<String, TyphonType> attributes;
	private Map<String, EntityModel> entities;
	
	public EntityModel(String entityName) {
		this(entityName, new HashMap<>(), new HashMap<>());
		
	}
	
	public EntityModel(String entityName, Map<String, TyphonType> attributes) {
		this(entityName, attributes, new HashMap<>());
		
	}


	public EntityModel(String entityName, Map<String, TyphonType> attributes, Map<String, EntityModel> entities) {
		super();
		this.entityName = entityName;
		this.attributes = attributes;
		this.entities = entities;
	}

	public String getEntityName() {
		return entityName;
	}

	public Map<String, TyphonType> getAttributes() {
		return attributes;
	}

	public Map<String, EntityModel> getEntities() {
		return entities;
	}

}
