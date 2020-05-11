package nl.cwi.swat.typhonql.backend;

import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

public abstract class Engine {
	protected ResultStore store;
	protected Map<String, String> uuids;
	protected List<Consumer<List<Record>>> script;
	protected List<Runnable> updates;

	public Engine(ResultStore store, List<Consumer<List<Record>>> script, List<Runnable> updates, Map<String, String> uuids) {
		this.store = store;
		this.script = script;
		this.updates = updates;
		this.uuids = uuids;
	}
	
	protected void storeResults(String resultId, ResultIterator results) {
		store.put(resultId,  results);
	}
	
}