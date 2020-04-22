package nl.cwi.swat.typhonql.backend.rascal;

import nl.cwi.swat.typhonql.client.DatabaseInfo;

public class ConnectionData {
	private final String host;
	private final int port;
	private final String user;
	private final String password;
	
	public ConnectionData(DatabaseInfo from) {
		this(from.getHost(), from.getPort(), from.getUser(), from.getPassword());
	}

	public ConnectionData(String host, int port, String user, String password) {
		this.host = host;
		this.port = port;
		this.user = user;
		this.password = password;
	}

	public String getHost() {
		return host;
	}

	public int getPort() {
		return port;
	}

	public String getUser() {
		return user;
	}

	public String getPassword() {
		return password;
	}
	

}
