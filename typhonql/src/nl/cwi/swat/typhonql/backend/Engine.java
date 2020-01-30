package nl.cwi.swat.typhonql.backend;

import java.util.LinkedHashMap;

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
		QueryExecutor executor = getExecutor(resultId, query, bindings);
		ResultIterator results = executor.executeSelect();
		store.put(resultId, results);
		return results;
	}

	protected abstract QueryExecutor getExecutor(String resultId, String query, LinkedHashMap<String, Binding> bindings);
	
}
