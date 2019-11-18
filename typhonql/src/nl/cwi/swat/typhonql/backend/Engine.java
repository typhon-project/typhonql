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
	
	public ResultIterator executeSelect(String resultId, String resultType, String query) {
		ResultIterator result = performSelect(resultType, query);
		store.put(resultId, result);
		return result;
	}

	public ResultIterator executeSelect(String resultId, String resultType, String query, Binding binding) {
		List<ResultIterator> lst = new ArrayList<>();
		ResultIterator results = store.getResults(binding.getReference());
		// TODO think about concurrency
		results.beforeFirst();
		while (results.hasNextResult()) {
			results.nextResult();
			
			if (!binding.getAttribute().isPresent()) {
				String uuid =results.getCurrentId();
				lst.add(performSelect(resultType, query, new Binding(binding.getId(), uuid)));
			}
			else {
				// TODO Assuming attributes are string is wrong
				Object field = results.getCurrentField(binding.getAttribute().get());
				lst.add(performSelect(resultType, query, new Binding(binding.getId(), (String) field)));
			}
		} 
		ResultIterator result = new AggregatedResultIterator(resultType, lst);
		store.put(resultId, result);
		return result ;
	}
 

	protected ResultIterator performSelect(String resultType, String query, Binding binding) {
		Map<String, String> map = new HashMap<String, String>();
		map.put(binding.getId(), binding.getReference());
		StringSubstitutor sub = new StringSubstitutor(map);
		String resolvedQuery = sub.replace(query);

		return performSelect(resultType, resolvedQuery);
	}

	protected abstract ResultIterator performSelect(String resultType, String query);
}
