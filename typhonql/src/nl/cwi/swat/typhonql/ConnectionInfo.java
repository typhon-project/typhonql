package nl.cwi.swat.typhonql;

import nl.cwi.swat.typhonql.client.DatabaseInfo;

public class ConnectionInfo {
	private final String polystoreId;
	private final DatabaseInfo databaseInfo;
	
	public ConnectionInfo(String polystoreId, String host, int port, String dbName, String dbms, String user,
			String password) {
		this(polystoreId, new DatabaseInfo(host, port, dbName, dbms, user, password));
	}
	
	public ConnectionInfo(String polystoreId, DatabaseInfo databaseInfo) {
		this.polystoreId = polystoreId;
		this.databaseInfo = databaseInfo;
	}
	
	public String getPolystoreId() {
		return polystoreId;
	}

	public DatabaseInfo getDatabaseInfo() {
		return databaseInfo;
	}	
}
