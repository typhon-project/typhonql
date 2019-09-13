package nl.cwi.swat.typhonql;

public class ConnectionInfo {
	private String host; 
	private int port; 
	private String dbName; 
	private DBType dbType; 
	private String dbms; 
	private String user; 
	private String password;
	
	public ConnectionInfo(String host, int port, String dbName, DBType dbType, String dbms, String user,
			String password) {
		super();
		this.host = host;
		this.port = port;
		this.dbName = dbName;
		this.dbType = dbType;
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
	
	public DBType getDbType() {
		return dbType;
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
	
}
