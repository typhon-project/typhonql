package nl.cwi.swat.typhonql.backend;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.rascalmpl.interpreter.utils.RuntimeExceptionFactory;
import org.rascalmpl.values.ValueFactoryFactory;

public abstract class UpdateExecutor {
	
	private ResultStore store;
	private List<Runnable> updates;
	private Map<String, Binding> bindings;
	private Map<String, UUID> uuids;

	public UpdateExecutor(ResultStore store, List<Runnable> updates, Map<String, UUID> uuids, Map<String, Binding> bindings) {
		this.store = store;
		this.updates = updates;
		this.bindings = bindings;
		this.uuids = uuids;
	}
	
	public void executeUpdate() {
		executeUpdate(new HashMap<>());
	}
	
	private void executeUpdate(Map<String, Object> values) {
		updates.add(() -> {  executeUpdateOperation(values); });
	}

	protected abstract void performUpdate(Map<String, Object> values);
	
	private void executeUpdateOperation(Map<String, Object> values) {
		if (values.size() == bindings.size()) {
			performUpdate(values); 
		}
		else {
			String var = bindings.keySet().iterator().next();
			Binding binding = bindings.get(var);
			if (binding instanceof Field) {
				Field field = (Field) binding;
				ResultIterator results =  store.getResults(field.getReference());
				if (results == null) {
					throw RuntimeExceptionFactory.illegalArgument(ValueFactoryFactory.getValueFactory().string(field.toString()), null, null, 
							"Results was null for field " + field.toString() + " and store " + store);
				}
				
				results.beforeFirst();
				
				while (results.hasNextResult()) {
					results.nextResult();
					Object value = (field.getAttribute().equals("@id"))? results.getCurrentId(field.getLabel(), field.getType()) : results.getCurrentField(field.getLabel(), field.getType(), field.getAttribute());
					values.put(var, value);
					executeUpdateOperation(values);
				}
			}
			else {
				GeneratedIdentifier id = (GeneratedIdentifier) binding;
				values.put(var, uuids.get(id.getName()));
				executeUpdateOperation(values);
			}
			
		}
	}
}
