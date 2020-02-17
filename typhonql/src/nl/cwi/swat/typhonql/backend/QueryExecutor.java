package nl.cwi.swat.typhonql.backend;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public abstract class QueryExecutor {
	
	private ResultStore store;
	private Map<String, Binding> bindings;

	public QueryExecutor(ResultStore store, String query, Map<String, Binding> bindings) {
		this.store = store;
		this.bindings = bindings;
	}
	
	public ResultIterator executeSelect() {
		return executeSelect(new HashMap<String, String>());
	}
	
	protected abstract ResultIterator performSelect(Map<String, String> values);
	
	private ResultIterator executeSelect(Map<String, String> values) {
		if (values.size() == bindings.size()) {
			return performSelect(values); 
		}
		else {
			List<ResultIterator> lst = new ArrayList<>();
			String var = bindings.keySet().iterator().next();
			Binding binding = bindings.get(var);
			ResultIterator results =  store.getResults(binding.getReference());
			results.beforeFirst();
			while (results.hasNextResult()) {
				results.nextResult();
				String value = (binding.getAttribute().equals("@id"))? serialize(results.getCurrentId(binding.getLabel(), binding.getType())) : serialize(results.getCurrentField(binding.getLabel(), binding.getType(), binding.getAttribute()));
				values.put(var, value);
				lst.add(executeSelect(values));
			}
			return new AggregatedResultIterator(lst);
		}
	}

	private String serialize(Object obj) {
		if (obj instanceof Integer) {
			return String.valueOf(obj);
		}
		else if (obj instanceof String) {
			return "\"" + (String) obj + "\"";
		}
		else
			throw new RuntimeException("Query executor does not know how to serialize object of type " +obj.getClass());
	}
}
