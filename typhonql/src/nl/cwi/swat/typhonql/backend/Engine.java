package nl.cwi.swat.typhonql.backend;

import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

public abstract class Engine {
	protected ResultStore store;
	protected Map<String, String> uuids;
	protected List<Consumer<List<Record>>> script;

	public Engine(ResultStore store, List<Consumer<List<Record>>> script, Map<String, String> uuids) {
		this.store = store;
		this.script = script;
		this.uuids = uuids;
	}
	
	protected void storeResults(String resultId, ResultIterator results) {
		store.put(resultId,  results);
	}
	
}