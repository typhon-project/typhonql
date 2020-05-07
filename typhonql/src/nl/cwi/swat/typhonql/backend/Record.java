package nl.cwi.swat.typhonql.backend;

import java.util.Map;

public class Record {
	private Map<Field, Object> objects;

	public Record(Map<Field, Object> objects) {
		super();
		this.objects = objects;
	}


	public Map<Field, Object> getObjects() {
		return objects;
	}

	public Object getObject(Field f) {
		return objects.get(f);
	}
	
}
