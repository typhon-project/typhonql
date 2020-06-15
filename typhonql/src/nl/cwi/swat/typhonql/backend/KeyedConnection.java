package nl.cwi.swat.typhonql.backend;

import java.util.Objects;
import nl.cwi.swat.typhonql.backend.rascal.ConnectionData;

public class KeyedConnection {
	
	private final String key;
	private final ConnectionData connection;
	
	public KeyedConnection(String key, ConnectionData connection) {
		this.key = key;
		this.connection = connection;
	}

	@Override
	public int hashCode() {
		return Objects.hash(connection, key);
	}

	@Override
	public boolean equals(Object obj) {
		if (this == obj) {
			return true;
		}
		if (obj instanceof KeyedConnection) {
			KeyedConnection other = (KeyedConnection) obj;
			return Objects.equals(connection, other.connection) && Objects.equals(key, other.key);
		}
		return false;
	}

	
}
