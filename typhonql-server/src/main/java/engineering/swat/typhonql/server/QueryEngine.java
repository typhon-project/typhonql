package engineering.swat.typhonql.server;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;
import nl.cwi.swat.typhonql.client.CommandResult;
import nl.cwi.swat.typhonql.client.DatabaseInfo;
import nl.cwi.swat.typhonql.client.XMIPolystoreConnection;
import nl.cwi.swat.typhonql.workingset.JsonSerializableResult;
import nl.cwi.swat.typhonql.workingset.WorkingSet;

public class QueryEngine {
	
	// every init will reset this backend, garbage collection takes care of clearing the evaluators
	private volatile XMIPolystoreConnection backend = null;

	private static final byte[] RESULT_OK_MESSAGE = "{\"result\":\"ok\"}".getBytes(StandardCharsets.UTF_8);
	private static JsonSerializableResult RESULT_OK = t -> t.write(RESULT_OK_MESSAGE);
	
	private XMIPolystoreConnection getBackend() throws IOException {
		XMIPolystoreConnection currentBackend = backend;
		if (currentBackend == null) {
			throw new IOException("Backend is not initialized yet");
		}
		return currentBackend;
	}

	public WorkingSet executeQuery(String query) throws IOException {
		return getBackend().executeQuery(query);
	}

	public CommandResult executeCommand(String cmd) throws IOException {
		return getBackend().executeUpdate(cmd);
	}

	public JsonSerializableResult initialize(String xmi, List<DatabaseInfo> databaseInfo) throws IOException {
		XMIPolystoreConnection newBackend = new XMIPolystoreConnection(xmi, databaseInfo);
		newBackend.prepareEvaluatorsInBackground(1);
		backend = newBackend;
		return RESULT_OK;
	}

	public JsonSerializableResult changeModel(String xmiModel) throws IOException {
		getBackend().setXmiModel(xmiModel);
		return RESULT_OK;
	}

	public JsonSerializableResult resetDatabase() throws IOException {
		getBackend().resetDatabases();
		return RESULT_OK;
	}

}
