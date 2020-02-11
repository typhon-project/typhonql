package nl.cwi.swat.typhonql.backend.rascal;

public class ConnectionData {
	private String host;
	private int port;
	private String user;
	private String password;

	public ConnectionData(String host, int port, String user, String password) {
		super();
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
