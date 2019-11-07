package nl.cwi.swat.typhonql.workingset;

import java.util.Map;
import java.util.stream.Collectors;

public class Entity {
	public String name;
	public String uuid;
	public Map<String, Object> fields;

	public Entity(String name, String uuid, Map<String, Object> fields) {
		super();
		this.name = name;
		this.uuid = uuid;
		this.fields = fields;
	}
	
	public String getName() {
		return name;
	}

	public String getUuid() {
		return uuid;
	}

	public Map<String, Object> getFields() {
		return fields;
	}

	@Override
	public String toString() {
		return "Entity " + name + "{ uuid: " + uuid +", fields: ["
				+ String.join(", ", fields.entrySet().stream().map(e -> e.getKey() + ":" + e.getValue())
						.collect(Collectors.toList()))
				+ "] }";
	}
	
	

}
