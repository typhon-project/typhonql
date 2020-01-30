package nl.cwi.swat.typhonql.client;

import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.Map.Entry;

import io.usethesource.vallang.IInteger;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;
import nl.cwi.swat.typhonql.workingset.WorkingSet;

public abstract class PolystoreConnection {
	
	
	
	public WorkingSet executeQuery(String query) {
		IValue val = evaluateQuery(query);
		System.out.println(val);
		if (val instanceof IMap) {
			return WorkingSet.fromIValue(val);
		}
		else
			throw new RuntimeException("Query was not from/select");
	}

	public CommandResult executeUpdate(String query) {
		IValue val = evaluateQuery(query);
		if (val instanceof IInteger) {
			return new CommandResult(((IInteger) val).intValue());
		} 
		else if (val instanceof ITuple) {
			ITuple tuple = (ITuple) val;
			IInteger n = (IInteger) tuple.get(0);
			IMap smap = (IMap) tuple.get(1);
			Map<String, String> map = new HashMap<String, String>();
			Iterator<Entry<IValue, IValue>> iter = smap.entryIterator();
			while (iter.hasNext()) {
				Entry<IValue, IValue> entry = iter.next();
				map.put(((IString) entry.getKey()).getValue(), ((IString) entry.getValue()).getValue());
			}
			return new CommandResult(((IInteger) n).intValue(), map);
		}
		else 
			throw new RuntimeException("Query was not an update query");
	}
	
	public abstract void resetDatabases(); 
	
	protected abstract IValue evaluateQuery(String query);
	

}