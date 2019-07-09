package nl.cwi.swat.typhonql;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IValue;
import typhonml.Model;

public final class Engine {
	
	private final Map<String, Object> connections;
	private Model schema;

	public Engine(typhonml.Model schema, Map<String, Object> connections) {
		this.schema = schema;
		this.connections = connections;
	}
	
	public void setSchema(typhonml.Model schema) {
		this.schema = schema;
	}
	
	public void execute(String statement, Object...params) {
		
	}

	
	public WorkingSet query(String query, Object... params) {
		return null;
	}
	
	public void insert(WorkingSet workingSet) {
		
	}
	
	public void delete(WorkingSet workingSet) {
		
	}
	
	public void update(WorkingSet workingSet) {
		
	}

	public WorkingSet query(String query) {
		IMap queries = partition(query, schema);
		List<WorkingSet> results = new ArrayList<>();
		
		
		return null; //recombine(queries.get("Java"), results);
	}

	private WorkingSet recombine(IValue iValue, List<WorkingSet> results) {
		// TODO Auto-generated method stub
		return null;
	}

	private IMap partition(String query, Model schema2) {
		// TODO Auto-generated method stub
		return null;
	}
	
	

}
