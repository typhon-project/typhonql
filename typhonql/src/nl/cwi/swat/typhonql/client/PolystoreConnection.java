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
		return CommandResult.fromIValue(val);
	}

	public CommandResult[] executePreparedUpdate(String preparedStatement, String[] columnNames, String[][] values) {
		IValue v = evaluatePreparedStatementQuery(preparedStatement, columnNames, values);
		Iterator<IValue> iter0 = ((IList) v).iterator();
		List<CommandResult> results = new ArrayList<CommandResult>();
		while (iter0.hasNext()) {
			IValue val = iter0.next();
			results.add(CommandResult.fromIValue(val));		
		}
		return results.toArray(new CommandResult[0]);
	}

	protected abstract IValue evaluatePreparedStatementQuery(String preparedStatement, String[] columnNames,
			String[][] matrix);

	public abstract void resetDatabases();

	public abstract ResultTable executeQuery(String query);
	
	protected abstract IValue evaluateUpdate(String update);
}