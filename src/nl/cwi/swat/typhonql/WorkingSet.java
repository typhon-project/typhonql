package nl.cwi.swat.typhonql;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Set;

public final class WorkingSet {

	// invariant: entity.getType().equals(key of this map)
	private final LinkedHashMap<String, List<Entity>>  entities;
	
	public WorkingSet() {
		entities = new LinkedHashMap<String, List<Entity>>();
	}
	
	public boolean add(Entity entity) {
		if (!entities.containsKey(entity.getType())) {
			entities.put(entity.getType(), new ArrayList<>());
		}
		return entities.get(entity.getType()).add(entity);
	}
	
	public void remove(Entity entity) {
		List<Entity> lst = entities.get(entity.getType());
		Iterator<Entity> iter = lst.iterator();
		while (iter.hasNext()) {
			Entity e = iter.next();
			if (e.getId().equals(entity.getId())) {
				iter.remove();
			}
		}
	}
	
	public Set<String> entityTypes() {
		return Collections.unmodifiableSet(entities.keySet());
	}
	
	
	
	public void addAll(WorkingSet other) {
		for (String type: other.entityTypes()) {
			for (Entity entity: other.each(type)) {
				add(entity);
			}
		}
	}
	
	public Iterable<Entity> each(String entityType) {
		return entities.get(entityType);
	}
	
	
	
}
