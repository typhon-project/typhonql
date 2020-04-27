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

	public ResultTable computeResultTable(List<Consumer<List<Record>>> script, List<Path> paths) {
		List<List<Record>> result = new ArrayList<List<Record>>();
		script.add((List<Record> row) -> {
			result.add(project(row, paths));
		});
		script.get(0).accept(new ArrayList<Record>());
		return toResultTable(paths, result);
	}

	private ResultTable toResultTable(List<Path> paths, List<List<Record>> result) {
		// TODO Auto-generated method stub
		List<String> columnNames = buildColumnNames(paths);
		List<Field> fields = paths.stream().map(p -> toField(p)).collect(Collectors.toList());
		List<List<Object>> values = toValues(fields, result);
		return new ResultTable(columnNames, values);
	}

	private Field toField(Path p) {
		return new Field(p.getDbName(), p.getVar(), p.getEntityType(), p.getSelectors()[0]);
	}

	private List<List<Object>> toValues(List<Field> fields, List<List<Record>> rs) {
		List<List<Object>> vs = new ArrayList<>();
		for (List<Record> records : rs) {
			List<Object> os = new ArrayList<Object>();
			for (Record r : records) {
				for (Field f : fields) {
					os.add(r.getObject(f));
				}
			}
			vs.add(os);
		}
		return vs;
	}

	private List<Record> project(List<Record> row, List<Path> paths) {
		List<Record> ls = new ArrayList<Record>();
		for (Record r : row) {
			ls.add(project(r, paths));
		}
		return ls;
	}

	private Field match(Record r, Path p) {
		for (Field f : r.getObjects().keySet()) {
			if (f.getLabel().equals(p.getVar()) && f.getType().equals(p.getEntityType())
					&& f.getAttribute().equals(p.getSelectors()[0]))
				return f;

		}
		return null;
	}

	private Record project(Record r, List<Path> paths) {
		Map<Field, Object> os = new HashMap<Field, Object>();
		for (Path p : paths) {
			Field f = match(r, p);
			if (f != null) {
				os.put(f, r.getObjects().get(f));
			}
		}
		return new Record(os);
	}

	private List<String> buildColumnNames(List<Path> paths) {
		List<String> names = new ArrayList<String>();
		for (Path path : paths) {
			List<String> name = new ArrayList<String>();
			name.add(path.getVar());
			for (String selector : path.getSelectors()) {
				name.add(selector);
			}
			names.add(String.join(".", name));
		}
		return names;
	}

	public void clear() {
		store.clear();
	}

}
