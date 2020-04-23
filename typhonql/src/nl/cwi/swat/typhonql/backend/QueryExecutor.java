package nl.cwi.swat.typhonql.backend;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.function.Consumer;

import nl.cwi.swat.typhonql.backend.rascal.Path;

public abstract class QueryExecutor {
	
	private ResultStore store;
	private List<Consumer<List<Record>>> script;
	private Map<String, Binding> bindings;
	private Map<Binding, String> inverseBindings;
	private Map<String, String> uuids;
	private List<Path> signature;

	public QueryExecutor(ResultStore store, List<Consumer<List<Record>>> script, Map<String, String> uuids, Map<String, Binding> bindings, List<Path> signature) {
		this.store = store;
		this.script = script;
		this.bindings = bindings;
		this.uuids = uuids;
		this.signature = signature;
		this.inverseBindings = new HashMap<Binding, String>();
		for (Entry<String, Binding> e : bindings.entrySet()) {
			inverseBindings.put(e.getValue(), e.getKey());
		}
	}
	
	public void executeSelect(String resultId) {
		int nxt = script.size() + 1;
	    script.add((List<Record> rows) -> {
	       Map<String, String> values = rowsToValues(rows);
	       ResultIterator iter = executeSelect(values);
	       this.storeResults(resultId, iter);
	       while (iter.hasNextResult()) {
	    	  iter.nextResult();
	    	  Record r = iter.buildRecord(signature);
	    	  List<Record> newRow = horizontalAdd(rows, r);
	    	  script.get(nxt).accept(newRow);
	       }
	    });
	}
	
	private Map<String, String> rowsToValues(List<Record> rows) {
		Map<String, String> values = new HashMap<String, String>();
		for (Record record : rows) {
			for (Field f : record.getObjects().keySet()) {
				if (inverseBindings.containsKey(f)) {
					String var = inverseBindings.get(f);
					values.put(var, serialize(record.getObject(f)));
				}
			}
		}
		return values;
	}
	
	private List<Record> horizontalAdd(List<Record> rows, Record r) {
		List<Record> result = new ArrayList<Record>();
		if (!rows.isEmpty()) { 
			for (Record row : rows) {
				result.add(horizontalAdd(row, r));
			}
			return result;
		}
		else
			return Arrays.asList(r);
	}

	private Record horizontalAdd(Record row, Record r) {
		Map<Field, String> map = new HashMap<>();
		map.putAll(row.getObjects());
		map.putAll(r.getObjects());
		return new Record(map);
	}

	public void executeSelect(String resultId, String query) {
		executeSelect(resultId, query);
	}
	
	protected abstract ResultIterator performSelect(Map<String, String> values);
	
	private ResultIterator executeSelect(Map<String, String> values) {
		if (values.size() == bindings.size()) {
			return performSelect(values); 
		}
		else {
			String var = bindings.keySet().iterator().next();
			Binding binding = bindings.get(var);
			if (binding instanceof Field) {
				List<ResultIterator> lst = new ArrayList<>();
				Field field = (Field) binding;
				ResultIterator results =  store.getResults(field.getReference());
				results.beforeFirst();
				while (results.hasNextResult()) {
					results.nextResult();
					String value = (field.getAttribute().equals("@id"))? serialize(results.getCurrentId(field.getLabel(), field.getType())) : serialize(results.getCurrentField(field.getLabel(), field.getType(), field.getAttribute()));
					values.put(var, value);
					lst.add(executeSelect(values));
				}
				return new AggregatedResultIterator(lst);
			}
			else {
				GeneratedIdentifier id = (GeneratedIdentifier) binding;
				values.put(id.getName(), uuids.get(id.getName()));
				return executeSelect(values);
			}
			
		}
	}
	
	protected void storeResults(String resultId, ResultIterator results) {
		store.put(resultId,  results);
	}

	private String serialize(Object obj) {
		if (obj == null) {
			return "null";
		}
		if (obj instanceof Integer) {
			return String.valueOf(obj);
		}
		else if (obj instanceof String) {
			return "\"" + (String) obj + "\"";
		}
		else
			throw new RuntimeException("Query executor does not know how to serialize object of type " +obj.getClass());
	}
}
