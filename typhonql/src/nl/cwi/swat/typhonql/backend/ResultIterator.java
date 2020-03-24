
package nl.cwi.swat.typhonql.backend;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import nl.cwi.swat.typhonql.backend.rascal.Path;

public interface ResultIterator {
	void nextResult();
	boolean hasNextResult();
	String getCurrentId(String label, String type);
	Object getCurrentField(String label, String type, String name);
	void beforeFirst();
	default Record buildRecord(List<Path> signature) {
		Map<Field, Object> vs = new HashMap<Field, Object>();
		for (Path p : signature) {
			Field f = toField(p);
			Object v = (f.getAttribute().equals("@id")) 
					? getCurrentId(f.getLabel(), f.getType())
					: getCurrentField(f.getLabel(), f.getType(), f.getAttribute());
			vs.put(f, v);
		}
		return new Record(vs);
	}
	
	default Field toField(Path p) {
		return new Field(p.getDbName(), p.getVar(), p.getEntityType(), p.getSelectors()[0]);
	}
}
