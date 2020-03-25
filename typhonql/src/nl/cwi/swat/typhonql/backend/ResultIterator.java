
package nl.cwi.swat.typhonql.backend;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import nl.cwi.swat.typhonql.backend.rascal.Path;

public interface ResultIterator {
	void nextResult();
	boolean hasNextResult();
	String getCurrentId(String label, String type);
	Object getCurrentField(String label, String type, String name);
	void beforeFirst();
	default Record buildRecord(List<Path> signature) {
		Map<Field, Object> vs = new HashMap<Field, Object>();
		if (signature.isEmpty())
			return new Record(vs);
		Path first = signature.get(0);
		Path id = new Path(first.getDbName(), first.getVar(), first.getEntityType(), new String[] { "@id" });
		for (Path p : Stream.concat(signature.stream(), Stream.of(id)).collect(Collectors.toList())) {
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
