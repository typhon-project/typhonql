package nl.cwi.swat.typhonql.backend.rascal;

import java.util.Arrays;

public class Path {
	private String dbName;
	private String var;
	private String entityType;
	private String[] selectors;
	
	public Path(String dbName, String var, String entityType, String[] selectors) {
		super();
		this.dbName = dbName;
		this.var = var;
		this.entityType = entityType;
		this.selectors = selectors;
	}
	
	public String getDbName() {
		return dbName;
	}
	public String getVar() {
		return var;
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
	
	@Override
	public int hashCode() {
		return dbName.hashCode() * 3 + var.hashCode() * 7 + entityType.hashCode() * 11 + Arrays.deepHashCode(selectors) * 13;
	}
	
	
}
