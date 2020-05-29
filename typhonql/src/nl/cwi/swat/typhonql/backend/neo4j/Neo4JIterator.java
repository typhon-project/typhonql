package nl.cwi.swat.typhonql.backend.neo4j;

import java.util.Iterator;
import java.util.List;

import org.neo4j.driver.Record;

import nl.cwi.swat.typhonql.backend.ResultIterator;

public class Neo4JIterator implements ResultIterator {

	private List<Record> records;
	private Iterator<Record> iterator;
	private Record current;
	
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
		return current.get("@id", "");
	}

	@Override
	public Object getCurrentField(String label, String type, String name) {
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	public void beforeFirst() {
		iterator = records.iterator();

	}

}
