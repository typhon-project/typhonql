package nl.cwi.swat.typhonql.client;

import java.io.IOException;
import java.io.OutputStream;
import java.util.HashMap;
import java.util.Map;
import nl.cwi.swat.typhonql.workingset.JsonSerializableResult;
import nl.cwi.swat.typhonql.workingset.json.WorkingSetJSON;

public class CommandResult implements JsonSerializableResult {
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

	@Override
	public void serializeJSON(OutputStream target) throws IOException {
		WorkingSetJSON.getMapper().writeValue(target, this);
	}

}
