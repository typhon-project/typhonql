package nl.cwi.swat.typhonql.backend.rascal;

public class Path {
	private String label;
	private String entityType;
	private String[] selectors;
	
	public Path(String label, String entityType, String[] selectors) {
		super();
		this.label = label;
		this.entityType = entityType;
		this.selectors = selectors;
	}
	
	public String getLabel() {
		return label;
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
