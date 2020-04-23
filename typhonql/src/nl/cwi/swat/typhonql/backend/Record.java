package nl.cwi.swat.typhonql.backend;

import java.util.Map;

public class Record {
	private Map<Field, String> objects;

	public Record(Map<Field, String> objects) {
		super();
		this.objects = objects;
	}


	public Map<Field, String> getObjects() {
		return objects;
	}

	public String getObject(Field f) {
		return objects.get(f);
	}
	
}
