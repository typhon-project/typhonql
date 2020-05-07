package nl.cwi.swat.typhonql.backend;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import java.util.stream.Collectors;

import nl.cwi.swat.typhonql.backend.rascal.Path;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

public class ResultStore {

	private Map<String, ResultIterator> store;

	public ResultStore() {
		store = new HashMap<String, ResultIterator>();
	}

	@Override
	public String toString() {
		return "RESULTSTORE(" + store.toString() + ")";
	}

	public ResultIterator getResults(String id) {
		return store.get(id);
	}

	public void put(String id, ResultIterator results) {
		store.put(id, results);
	}

	public void clear() {
		store.clear();
	}

}
