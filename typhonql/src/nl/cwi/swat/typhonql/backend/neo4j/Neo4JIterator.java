package nl.cwi.swat.typhonql.backend.neo4j;

import java.util.Iterator;
import java.util.List;

import org.neo4j.driver.Record;
import org.neo4j.driver.Value;
import org.neo4j.driver.internal.types.InternalTypeSystem;
import org.neo4j.driver.types.TypeSystem;

import nl.cwi.swat.typhonql.backend.ResultIterator;

public class Neo4JIterator implements ResultIterator {

	private List<Record> records;
	private Iterator<Record> iterator;
	private Record current;
	private static TypeSystem TYPES = InternalTypeSystem.TYPE_SYSTEM;
	
	public Neo4JIterator(List<Record> records) {
		this.records = records;
		this.iterator = records.iterator();
	}

	@Override
	public void nextResult() {
		this.current = iterator.next();
	}

	@Override
	public boolean hasNextResult() {
		// TODO Auto-generated method stub
		return iterator.hasNext();
	}

	@Override
	public String getCurrentId(String label, String type) {
		return current.get(label + "." + type + ".@id", "");
	}
	
	@Override
	public Object getCurrentField(String label, String type, String name) {
		Value v = current.get(label + "." + type + "." + name);
		return getFieldForType(v);
	}

	private Object getFieldForType(Value v) {
		if (v.hasType(TYPES.STRING())) {
			return v.asString();
		}
		else if (v.hasType(TYPES.BOOLEAN())) {
			return v.asBoolean();
		}
		else if (v.hasType(TYPES.INTEGER())) {
			return v.asInt();
		}
		else
			throw new RuntimeException("There is no mapper for Neo4J type " + v.type());
	}

	@Override
	public void beforeFirst() {
		iterator = records.iterator();

	}

}
