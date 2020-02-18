package nl.cwi.swat.typhonql.backend;

import java.util.Map;

public abstract class Engine {
	protected ResultStore store;
	protected Map<String, String> uuids;

	public Engine(ResultStore store, Map<String, String> uuids) {
		this.store = store;
		this.uuids = uuids;
	}
	
	protected void storeResults(String resultId, ResultIterator results) {
		store.put(resultId,  results);
	}
	
}