package nl.cwi.swat.typhonql.client;

import io.usethesource.vallang.IInteger;
import io.usethesource.vallang.IMap;
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

	public int executeUpdate(String query) {
		IValue val = evaluateQuery(query);
		if (val instanceof IInteger) {
			return ((IInteger) val).intValue();
		} else 
			throw new RuntimeException("Query was not an update query");
	}
	
	public abstract void resetDatabases(); 
	
	protected abstract IValue evaluateQuery(String query);
	

}