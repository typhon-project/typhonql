package nl.cwi.swat.typhonql.client;

import nl.cwi.swat.typhonql.DBType;

public class DatabaseInfo {
	
	private final String host; 
	private final int port; 
	private final String dbName; 
	private final String dbms; 
	private final String user; 
	private final String password;
	
	public DatabaseInfo(String host, int port, String dbName, String dbms, String user,
			String password) {
		this.host = host;
		this.port = port;
		this.dbName = dbName;
		this.dbms = dbms;
		this.user = user;
		this.password = password;
	}

	
	public String getHost() {
		return host;
	}
	
	public int getPort() {
		return port;
	}
	
	public String getDbName() {
		return dbName;
	}
	
	public String getDbms() {
		return dbms;
	}
	
	public String getUser() {
		return user;
	}
	
	public String getPassword() {
		return password;
	}


	@Override
	public String toString() {
		return "DatabaseInfo [host=" + host + ", port=" + port + ", dbName=" + dbName +
			   ", dbms=" + dbms + ", user=" + user + ", password=" + password + "]";
	}
	
	
}
