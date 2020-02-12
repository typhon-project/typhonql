package nl.cwi.swat.typhonql.backend;

public abstract class Engine {
	protected ResultStore store;

	public Engine(ResultStore store) {
		this.store = store;
	}
	
	protected void storeResults(String resultId, ResultIterator results) {
		store.put(resultId,  results);
	}
	
}