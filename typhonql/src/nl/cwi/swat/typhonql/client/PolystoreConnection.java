package nl.cwi.swat.typhonql.client;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;

import io.usethesource.vallang.IInteger;
import io.usethesource.vallang.IList;
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
		} else
			throw new RuntimeException("Query was not from/select");
	}

	public CommandResult executeUpdate(String query) {
		IValue val = evaluateQuery(query);
		if (val instanceof IInteger) {
			return new CommandResult(((IInteger) val).intValue());
		} else if (val instanceof ITuple) {
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
		} else
			throw new RuntimeException("Query was not an update query");
	}

	public CommandResult[] executePreparedUpdate(String preparedStatement, Object[][] matrix) {
		IValue v = evaluatePreparedStatementQuery(preparedStatement, matrix);
		if (v instanceof IList) {
			Iterator<IValue> iter0 = ((IList) v).iterator();
			List<CommandResult> results = new ArrayList<CommandResult>();
			while (iter0.hasNext()) {
				IValue val = iter0.next();
				if (val instanceof ITuple) {
					ITuple tuple = (ITuple) val;
					IInteger n = (IInteger) tuple.get(0);
					IMap smap = (IMap) tuple.get(1);
					Map<String, String> map = new HashMap<String, String>();
					Iterator<Entry<IValue, IValue>> iter = smap.entryIterator();
					while (iter.hasNext()) {
						Entry<IValue, IValue> entry = iter.next();
						map.put(((IString) entry.getKey()).getValue(), ((IString) entry.getValue()).getValue());
					}
					results.add(new CommandResult(((IInteger) n).intValue(), map));
				} else
					throw new RuntimeException("Each result row must be a tuple");
			}
			return results.toArray(new CommandResult[0]);
		} else
			throw new RuntimeException("The result must be a list");
	}

	protected abstract IValue evaluatePreparedStatementQuery(String preparedStatement, Object[][] matrix);

	public abstract void resetDatabases();


	protected abstract IValue evaluateQuery(String query);
}