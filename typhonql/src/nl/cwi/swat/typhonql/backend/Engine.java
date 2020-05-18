package nl.cwi.swat.typhonql.backend;

import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

public abstract class Engine {
	protected final ResultStore store;
	protected final Map<String, String> uuids;
	protected final List<Consumer<List<Record>>> script;
	protected final List<Runnable> updates;

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