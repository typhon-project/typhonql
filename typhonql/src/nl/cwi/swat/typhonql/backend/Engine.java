package nl.cwi.swat.typhonql.backend;

import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;

public abstract class Engine {
	protected ResultStore store;

	public Engine(ResultStore store) {
		this.store = store;

	}
	public ResultIterator executeSelect(String resultId, String query) {
		return executeSelect(resultId, query, new LinkedHashMap<String, Binding>());
	}
	
	public ResultIterator executeSelect(String resultId, String query,
			LinkedHashMap<String, Binding> bindings) {
		ResultIterator results = executeSelect(resultId, query, bindings, new HashMap<String, String>());
		store.put(resultId, results);
		return results;
	}

	protected abstract ResultIterator executeSelect(String resultId, String query, LinkedHashMap<String, Binding> bindings, Map<String, String> values);
}
