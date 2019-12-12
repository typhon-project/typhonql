package nl.cwi.swat.typhonql.backend;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

public abstract class SQLEngine extends Engine {
	private String host;
	private int port;
	private String dbName;
	private String user;
	private String password;

	public SQLEngine(ResultStore store, String host, int port, String dbName, String user, String password) {
		super(store);
		this.host = host;
		this.port = port;
		this.dbName = dbName;
		this.user = user;
		this.password = password;

		initializeDriver();
	}

	protected abstract void initializeDriver();

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

	public abstract String getConnectionString(String host, int port, String dbName, String user, String password);

}
