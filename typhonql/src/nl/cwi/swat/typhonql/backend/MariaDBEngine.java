package nl.cwi.swat.typhonql.backend;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.Map;

public class MariaDBEngine extends SQLEngine {

	private String host;
	private int port;
	private String dbName;
	private String user;
	private String password;

	public MariaDBEngine(ResultStore store, String host, int port, String dbName, String user, String password) {
		super(store, host, port, dbName, user, password);
		initializeDriver();
	}

	@Override
	protected ResultIterator performSelect(String query) {
		try {
			Connection connection = DriverManager
					.getConnection(getConnectionString(host, port, dbName, user, password));
			Statement stmt = connection.createStatement();
			ResultSet rs = stmt.executeQuery(query);
			return new SQLResultIterator(rs);

		} catch (SQLException e1) {
			throw new RuntimeException(e1);
		}
	}
	
	@Override
	protected ResultIterator performSelect(String query, Map<String, String> bindings) {
		try {
			Connection connection = DriverManager
					.getConnection(getConnectionString(host, port, dbName, user, password));
			Statement stmt = connection.createStatement();
			ResultSet rs = stmt.executeQuery(query);
			return new SQLResultIterator(rs);

		} catch (SQLException e1) {
			throw new RuntimeException(e1);
		}
	}

	@Override
	protected void initializeDriver() {
		try {
			Class.forName("org.mariadb.jdbc.Driver");
		} catch (ClassNotFoundException e) {
			throw new RuntimeException("MariaDB driver not found", e);
		}		
	}
	
	@Override
	public String getConnectionString(String host, int port, String dbName, String user, String password) {
		return "jdbc:mariadb://" + host + ":" + port + "/" + dbName + "?user=" + user + "&password=" + password;
	}

}
