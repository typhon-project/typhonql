package nl.cwi.swat.typhonql;

import nl.cwi.swat.typhonql.client.DatabaseInfo;

public class ConnectionInfo {
	private String polystoreId;
	private DatabaseInfo databaseInfo;
	
	public ConnectionInfo(String polystoreId, String host, int port, String dbName, String dbms, String user,
			String password) {
		super();
		this.polystoreId = polystoreId;
		this.databaseInfo = new DatabaseInfo(host, port, dbName, DBType.valueOf(dbms), user, password);
	}
	
	public ConnectionInfo(String polystoreId, DatabaseInfo databaseInfo) {
		super();
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
