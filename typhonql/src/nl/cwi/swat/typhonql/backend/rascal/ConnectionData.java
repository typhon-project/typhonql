package nl.cwi.swat.typhonql.backend.rascal;

import java.util.Objects;
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

	@Override
	public int hashCode() {
		return Objects.hash(host, password, port, user);
	}

	@Override
	public boolean equals(Object obj) {
		if (this == obj) {
			return true;
		}
		if (obj instanceof ConnectionData) {
			ConnectionData other = (ConnectionData) obj;
			return Objects.equals(host, other.host) && Objects.equals(password, other.password)
					&& port == other.port && Objects.equals(user, other.user);
		}
		return false;
	}
	
	
	

}
