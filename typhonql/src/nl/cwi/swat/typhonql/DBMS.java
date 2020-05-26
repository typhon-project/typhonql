package nl.cwi.swat.typhonql;

import java.util.Optional;

public interface DBMS {
	String getName();
	String getConnectionString(String host, int port, String dbName, String user, String password);
	void initializeDriver();
	static Optional<DBMS> forName(String dbType) {
		switch (dbType.toLowerCase()) {
		case "mariadb":
			return Optional.of(new MariaDB());
		case "mongodb":
			return Optional.of(new MongoDB());
		default:
			return Optional.empty();
		}
	}
}
