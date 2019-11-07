package nl.cwi.swat.typhonql.workingset;

import java.util.HashMap;
import java.util.List;

import io.usethesource.vallang.IValue;

@SuppressWarnings("serial")
public class WorkingSet extends HashMap<String, List<Entity>>{
	
	public static WorkingSet fromIValue(IValue v) {
		WorkingSet ws = new WorkingSet();
		
		return ws;
		
	}
}
