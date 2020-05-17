package nl.cwi.swat.typhonql.backend.mariadb;

import java.sql.Connection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.Engine;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.rascal.Path;

public class MariaDBEngine extends Engine {

	private final Connection connection;

	public MariaDBEngine(ResultStore store, List<Consumer<List<Record>>> script, List<Runnable> updates, Map<String, String> uuids, Connection sqlConnection) {
		super(store, script, updates, uuids);
		this.connection = sqlConnection;
	}

	public void executeSelect(String resultId, String query, List<Path> signature) {
		new MariaDBQueryExecutor(store, script, uuids, signature, query, new HashMap<String, Binding>(), connection).executeSelect(resultId);
	}

	public void executeSelect(String resultId, String query, Map<String, Binding> bindings, List<Path> signature) {
		new MariaDBQueryExecutor(store, script, uuids, signature, query, bindings, connection).executeSelect(resultId);
	}

	public void executeUpdate(String query, Map<String, Binding> bindings) {
		new MariaDBUpdateExecutor(store, updates, uuids, query, bindings, connection).executeUpdate();		
	}

}
