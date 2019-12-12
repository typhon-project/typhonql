package nl.cwi.swat.typhonql.backend;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

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
				Entity e = createEntity(iter, model);
				ws.get(entityLabel).add(e);
			}
		}

		return ws;
	}

	private Entity createEntity(ResultIterator iter, EntityModel model) {
		Map<String, Object> fields = new HashMap<String, Object>();
		for (String attributeName : model.getAttributes().keySet()) {
			Object obj = iter.getCurrentField(model.getEntityName(), attributeName);
			fields.put(attributeName, obj);
		}

		Entity e = new Entity(model.getEntityName(), iter.getCurrentId(model.getEntityName()), fields);

		return e;
	}

	public void clear() {
		store.clear();
	}

}
