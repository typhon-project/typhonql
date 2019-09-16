package nl.cwi.swat.typhonql;

public class MongoDB implements DBMS {

	@Override
	public String getName() {
		return "MongoDb";
	}

	@Override
	public String getConnectionString(String host, int port, String dbName, String user, String password) {
		return "mongodb://" + user + ":" + password + "@" + host + ":" + port;
	}

	@Override
	public void initializeDriver() {
		
	}
}
