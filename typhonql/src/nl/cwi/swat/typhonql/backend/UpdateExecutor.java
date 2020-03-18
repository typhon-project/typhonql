package nl.cwi.swat.typhonql.backend;

import java.util.HashMap;
import java.util.Map;

public abstract class UpdateExecutor {
	
	private ResultStore store;
	private Map<String, Binding> bindings;
	private Map<String, String> uuids;

	public UpdateExecutor(ResultStore store, Map<String, String> uuids, Map<String, Binding> bindings) {
		this.store = store;
		this.bindings = bindings;
		this.uuids = uuids;
	}
	
	public void executeUpdate() {
		executeUpdate(new HashMap<String, String>());
	}
	
	protected abstract void performUpdate(Map<String, String> values);
	
	private void executeUpdate(Map<String, String> values) {
		if (values.size() == bindings.size()) {
			performUpdate(values); 
		}
		else {
			String var = bindings.keySet().iterator().next();
			Binding binding = bindings.get(var);
			if (binding instanceof Field) {
				Field field = (Field) binding;
				ResultIterator results =  store.getResults(field.getReference());
				results.beforeFirst();
				while (results.hasNextResult()) {
					results.nextResult();
					String value = (field.getAttribute().equals("@id"))? serialize(results.getCurrentId(field.getLabel(), field.getType())) : serialize(results.getCurrentField(field.getLabel(), field.getType(), field.getAttribute()));
					values.put(var, value);
					executeUpdate(values);
				}
			}
			else {
				GeneratedIdentifier id = (GeneratedIdentifier) binding;
				values.put(var, serialize(uuids.get(id.getName())));
				executeUpdate(values);
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
