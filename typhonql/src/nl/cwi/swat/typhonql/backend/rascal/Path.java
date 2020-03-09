package nl.cwi.swat.typhonql.backend.rascal;

public class Path {
	private String entity;
	private String entityType;
	private String[] selectors;
	
	public Path(String entity, String entityType, String[] selectors) {
		super();
		this.entity = entity;
		this.entityType = entityType;
		this.selectors = selectors;
	}
	
	public String getEntity() {
		return entity;
	}
	public String getEntityType() {
		return entityType;
	}
	public String[] getSelectors() {
		return selectors;
	}
	
	public boolean isRoot() {
		if (selectors == null)
			return true;
		else if (selectors.length == 0)
			return true;
		else 
			return false;
	}
	
	
}
