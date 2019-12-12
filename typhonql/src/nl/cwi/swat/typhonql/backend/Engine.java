package nl.cwi.swat.typhonql.backend;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.apache.commons.text.StringSubstitutor;

public abstract class Engine {
	private ResultStore store;

	public Engine(ResultStore store) {
		this.store = store;

	}

	private ResultIterator executeSelect(String[] resultTypes, String query,
			Map<String, Binding> bindings) {
		if (bindings.isEmpty()) {
			return performSelect(query); 
		}
		else {
			List<ResultIterator> lst = new ArrayList<>();
			String var = bindings.keySet().iterator().next();
			Binding binding = bindings.get(var);
			bindings.remove(var);
			ResultIterator results =  store.getResults(binding.getReference());
			results.beforeFirst();
			while (results.hasNextResult()) {
				results.nextResult();
				String value = (binding.getAttribute().equals("@id"))? results.getCurrentId(binding.getType()) : (String) results.getCurrentField(binding.getType(), binding.getAttribute());
				Map<String, String> toReplace = new HashMap<String, String>();
				toReplace.put(var, value);
				StringSubstitutor sub = new StringSubstitutor(toReplace);
				String resolvedQuery = sub.replace(query);
				lst.add(executeSelect(resultTypes, resolvedQuery, bindings));
			}
			return new AggregatedResultIterator(lst);
		}
	}
	
	public ResultIterator executeSelect(String resultId, String[] resultTypes, String query) {
		return executeSelect(resultId, resultTypes, query, new HashMap<String, Binding>());
	}
	
	public ResultIterator executeSelect(String resultId, String[] resultTypes, String query,
			Map<String, Binding> bindings) {
		ResultIterator results = executeSelect(resultTypes,query, bindings);
		store.put(resultId, results);
		return results;
	}

	protected ResultIterator performSelect(String query, Map<String, String> bindings) {
		StringSubstitutor sub = new StringSubstitutor(bindings);
		String resolvedQuery = sub.replace(query);

		return performSelect(resolvedQuery);
	}

	protected abstract ResultIterator performSelect(String query);
}
