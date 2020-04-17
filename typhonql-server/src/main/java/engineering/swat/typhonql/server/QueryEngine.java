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
	private static final byte[] RESULT_OK_MESSAGE = "{\"result\":\"ok\"}".getBytes(StandardCharsets.UTF_8);
	private static JsonSerializableResult RESULT_OK = t -> t.write(RESULT_OK_MESSAGE);

	private final XMIPolystoreConnection backend;
	
	public QueryEngine() throws IOException {
		backend = new XMIPolystoreConnection();
	}

	private volatile String lastXMI = null; // only for backwards compatiblity phase
	private volatile List<DatabaseInfo> lastDBs = null;
    

	public ResultTable executeQuery(String xmi, List<DatabaseInfo> databaseInfo, String query) throws IOException {
		return backend.executeQuery(supportOldAPI(xmi), supportOldAPI(databaseInfo), query);
	}

	private List<DatabaseInfo> supportOldAPI(List<DatabaseInfo> databaseInfo) {
		if (databaseInfo == null || databaseInfo.isEmpty()) {
			return lastDBs;
		}
		lastDBs = databaseInfo;
		return databaseInfo;
	}

	private String supportOldAPI(String xmi) {
		if (xmi == null || xmi.isEmpty()) {
			return lastXMI;
		}
		lastXMI = xmi;
		return xmi;
	}

	public CommandResult executeCommand(String xmi, List<DatabaseInfo> databaseInfo, String cmd) throws IOException {
		return backend.executeUpdate(supportOldAPI(xmi), supportOldAPI(databaseInfo), cmd);
	}
	
	public JsonSerializableResult executeDDL(String xmi, List<DatabaseInfo> databaseInfo, String cmd) throws IOException {
		backend.executeDDLUpdate(supportOldAPI(xmi), supportOldAPI(databaseInfo), cmd);
		return RESULT_OK;
	}

	public JsonSerializableResult initialize(String xmi, List<DatabaseInfo> databaseInfo) throws IOException {
		// TODO remove after migrating polystore API
		lastDBs = databaseInfo;
		lastXMI = xmi;
		return RESULT_OK;
	}

	public JsonSerializableResult changeModel(String xmi, List<DatabaseInfo> databaseInfo) throws IOException {
		// TODO remove after migrating polystore API
		lastDBs = databaseInfo;
		lastXMI = xmi;
		return RESULT_OK;
	}

	public JsonSerializableResult resetDatabase(String xmi, List<DatabaseInfo> databaseInfo) throws IOException {
		backend.resetDatabases(supportOldAPI(xmi), supportOldAPI(databaseInfo));
		return RESULT_OK;
	}

	public CommandResult[] executeCommand(String xmi, List<DatabaseInfo> databaseInfo,String command, String[] parameterNames, String[][] boundRows) throws IOException {
		return backend.executePreparedUpdate(supportOldAPI(xmi), supportOldAPI(databaseInfo), command, parameterNames, boundRows);
	}

}
