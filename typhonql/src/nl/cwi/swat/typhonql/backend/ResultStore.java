package nl.cwi.swat.typhonql.backend;

import java.io.InputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import java.util.stream.Collectors;

import nl.cwi.swat.typhonql.backend.rascal.Path;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

public class ResultStore {

	private final Map<String, ResultIterator> store;
	private final Map<String, InputStream> fileMap;

	public ResultStore(Map<String, InputStream> fileMap) {
		store = new HashMap<String, ResultIterator>();
		this.fileMap = fileMap;
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
	
	public InputStream getFile(String key) {
		return fileMap.get(key);
	}

}
