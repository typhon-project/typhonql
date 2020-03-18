package engineering.swat.typhonql.server;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;

import nl.cwi.swat.typhonql.client.CommandResult;
import nl.cwi.swat.typhonql.client.DatabaseInfo;
import nl.cwi.swat.typhonql.client.XMIPolystoreConnection;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;
import nl.cwi.swat.typhonql.workingset.JsonSerializableResult;

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

	public ResultTable executeQuery(String query) throws IOException {
		return getBackend().executeQuery(query);
	}

	public CommandResult executeCommand(String cmd) throws IOException {
		return getBackend().executeUpdate(cmd);
	}
	
	public JsonSerializableResult executeDDL(String cmd) throws IOException {
		getBackend().executeDDLUpdate(cmd);
		return RESULT_OK;
	}

	public JsonSerializableResult initialize(String xmi, List<DatabaseInfo> databaseInfo) throws IOException {
		backend = new XMIPolystoreConnection(xmi, databaseInfo);
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

	public CommandResult[] executeCommand(String command, String[] parameterNames, String[][] boundRows) throws IOException {
		return getBackend().executePreparedUpdate(command, parameterNames, boundRows);
	}

}
