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
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

public abstract class PolystoreConnection {

	public CommandResult executeUpdate(String query) {
		IValue val = evaluateUpdate(query);
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

	public CommandResult[] executePreparedUpdate(String preparedStatement, String[] columnNames, String[][] values) {
		IValue v = evaluatePreparedStatementQuery(preparedStatement, columnNames, values);
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

	protected abstract IValue evaluatePreparedStatementQuery(String preparedStatement, String[] columnNames,
			String[][] matrix);

	public abstract void resetDatabases();

	public abstract ResultTable executeQuery(String query);
	
	protected abstract IValue evaluateUpdate(String update);
}