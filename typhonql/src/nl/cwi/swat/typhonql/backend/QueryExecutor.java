package nl.cwi.swat.typhonql.backend;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public abstract class QueryExecutor {
	
	private ResultStore store;
	private Map<String, Binding> bindings;
	private Map<String, String> uuids;

	public QueryExecutor(ResultStore store, Map<String, String> uuids, Map<String, Binding> bindings) {
		this.store = store;
		this.bindings = bindings;
		this.uuids = uuids;
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
			String var = bindings.keySet().iterator().next();
			Binding binding = bindings.get(var);
			if (binding instanceof Field) {
				List<ResultIterator> lst = new ArrayList<>();
				Field field = (Field) binding;
				ResultIterator results =  store.getResults(field.getReference());
				results.beforeFirst();
				while (results.hasNextResult()) {
					results.nextResult();
					String value = (field.getAttribute().equals("@id"))? serialize(results.getCurrentId(field.getLabel(), field.getType())) : serialize(results.getCurrentField(field.getLabel(), field.getType(), field.getAttribute()));
					values.put(var, value);
					lst.add(executeSelect(values));
				}
				return new AggregatedResultIterator(lst);
			}
			else {
				GeneratedIdentifier id = (GeneratedIdentifier) binding;
				values.put(id.getName(), uuids.get(id.getName()));
				return executeSelect(values);
			}
			
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
