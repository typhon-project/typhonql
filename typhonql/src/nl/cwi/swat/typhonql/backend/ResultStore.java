package nl.cwi.swat.typhonql.backend;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import nl.cwi.swat.typhonql.backend.rascal.Path;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;
import nl.cwi.swat.typhonql.workingset.Entity;
import nl.cwi.swat.typhonql.workingset.WorkingSet;

public class ResultStore {

	private Map<String, ResultIterator> store;

	public ResultStore() {
		store = new HashMap<String, ResultIterator>();
	}

	public ResultIterator getResults(String id) {
		return store.get(id);
	}

	public void put(String id, ResultIterator results) {
		store.put(id, results);
	}
	
	public ResultTable computeResultTable(String resultName, List<Path> paths) {
		ResultIterator iter = store.get(resultName);
		iter.beforeFirst();
		List<List<Object>> vs = new ArrayList<List<Object>>();
		while (iter.hasNextResult()) {
			iter.nextResult();
			List<Object> os = new ArrayList<Object>();
			for (Path path : paths) {
				Object obj = null;
				if (path.isRoot()) {
					obj = iter.getCurrentField(path.getEntity(), path.getEntityType(), "@id");
				}
				else {
					if (path.getSelectors().length == 1) {
						obj = iter.getCurrentField(path.getEntity(), path.getEntityType(), path.getSelectors()[0]);
					}
					else {
						// TODO
						throw new RuntimeException("Not implemented access for paths longer than 2");
					}
				}
				os.add(obj);
			}
			vs.add(os);
		}
		return new ResultTable(buildColumnNames(paths), vs);
	}

	private List<String> buildColumnNames(List<Path> paths) {
		List<String> names = new ArrayList<String>();
		for (Path path : paths) {
			List<String> name = new ArrayList<String>();
			name.add(path.getEntity());
			for (String selector : path.getSelectors()) {
				name.add(selector);
			}
			names.add(String.join(".", name));
		}
		return names;
	}

	public WorkingSet computeResult(String resultName, String[] entityLabels, EntityModel... models) {
		if (entityLabels == null || entityLabels.length < 1) {
			throw new RuntimeException("At least one entity label must be provided");
		}
		if (models == null || models.length < 1) {
			throw new RuntimeException("At least one entity model must be provided");
		}
		WorkingSet ws = new WorkingSet();
		ResultIterator iter = store.get(resultName);
		
		for (String name : entityLabels) {
			ws.put(name, new ArrayList<>());
		}
		
		iter.beforeFirst();

		while (iter.hasNextResult()) {
			iter.nextResult();
			for (int i = 0; i < entityLabels.length; i++) {
				String entityLabel = entityLabels[i];
				EntityModel model = models[i];
				Entity e = createEntity(iter, entityLabel, model);
				ws.get(entityLabel).add(e);
			}
		}

		return ws;
	}

	private Entity createEntity(ResultIterator iter, String entityLabel, EntityModel model) {
		Map<String, Object> fields = new HashMap<String, Object>();
		for (String attributeName : model.getAttributes().keySet()) {
			Object obj = iter.getCurrentField(entityLabel, model.getEntityName(), attributeName);
			fields.put(attributeName, obj);
		}

		Entity e = new Entity(model.getEntityName(), iter.getCurrentId(entityLabel, model.getEntityName()), fields);

		return e;
	}

	public void clear() {
		store.clear();
	}

}
