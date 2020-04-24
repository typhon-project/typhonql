package nl.cwi.swat.typhonql.client.resulttable;

import com.fasterxml.jackson.databind.annotation.JsonDeserialize;

@JsonDeserialize
public class EntityRef {

	private String uuid;
	
	public EntityRef() {
		super();
	}

	public EntityRef(String uuid) {
		super();
		this.uuid = uuid;
	}

	public String getUuid() {
		return uuid;
	}
	
	
}
