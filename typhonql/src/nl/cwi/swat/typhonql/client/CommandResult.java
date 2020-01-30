package nl.cwi.swat.typhonql.client;

import java.util.HashMap;
import java.util.Map;

public class CommandResult {
	private int affectedEntities;
	private Map<String, String> createdUuids;
	
	public CommandResult(int affectedEntities, Map<String, String> createdUuids) {
		super();
		this.affectedEntities = affectedEntities;
		this.createdUuids = createdUuids;
	}
	
	public CommandResult(int affectedEntities) {
		super();
		this.affectedEntities = affectedEntities;
		this.createdUuids = new HashMap<String, String>();
	}

	public int getAffectedEntities() {
		return affectedEntities;
	}

	public Map<String, String> getCreatedUuids() {
		return createdUuids;
	}

}
