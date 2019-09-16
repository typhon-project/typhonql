package nl.cwi.swat.typhonql;

public interface DBMS {
	String getName();
	String getConnectionString(String host, int port, String dbName, String user, String password);
	void initializeDriver();
}
