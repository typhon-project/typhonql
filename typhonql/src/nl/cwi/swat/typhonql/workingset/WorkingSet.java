package nl.cwi.swat.typhonql.workingset;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;

import io.usethesource.vallang.IList;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.IValue;

@SuppressWarnings("serial")
public class WorkingSet extends HashMap<String, List<Entity>>{
	
	public static WorkingSet fromIValue(IValue v) {
		//map[str entity, list[Entity] entities];
		if (v instanceof IMap) {
			IMap map = (IMap) v;
			WorkingSet ws = new WorkingSet();
			Iterator<Entry<IValue, IValue>> iter = map.entryIterator();
			while (iter.hasNext()) {
				Entry<IValue, IValue> entry = iter.next();
				IString key = (IString) entry.getKey();
				IList entries = (IList) entry.getValue();
				Iterator<IValue> entryIter = entries.iterator();
				List<Entity> entities = new ArrayList<Entity>();
				while (entryIter.hasNext()) {
					IValue current = entryIter.next();
					Entity e = Entity.fromIValue(entry.getValue());
					entities.add(e);
				}
				
				ws.put(key.getValue(), entities);
			}
			return ws;
		}
		else
			throw new RuntimeException("IValue does not represent a working set");
		
	}
}
