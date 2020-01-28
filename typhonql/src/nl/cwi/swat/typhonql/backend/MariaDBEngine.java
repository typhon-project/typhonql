package nl.cwi.swat.typhonql.backend;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class MariaDBEngine extends Engine {

	private String host;
	private int port;
	private String dbName;
	private String user;
	private String password;

	public MariaDBEngine(ResultStore store, String host, int port, String dbName, String user, String password) {
		super(store);
		this.host = host;
		this.port = port;
		this.dbName = dbName;
		this.user = user;
		this.password = password;
		initializeDriver();
	}

	
	protected ResultIterator performSelect(PreparedStatement pstmt, List<String> bindings) {
		try {
			for (int i = 0 ; i < bindings.size() ; i++) {
				pstmt.setString(i + 1, bindings.get(i));
			}
			ResultSet rs = pstmt.executeQuery(); 
			return new SQLResultIterator(rs);

		} catch (SQLException e1) {
			throw new RuntimeException(e1);
		}
	}

	protected void initializeDriver() {
		try {
			Class.forName("org.mariadb.jdbc.Driver");
		} catch (ClassNotFoundException e) {
			throw new RuntimeException("MariaDB driver not found", e);
		}		
	}
	
	public String getConnectionString(String host, int port, String dbName, String user, String password) {
		return "jdbc:mariadb://" + host + ":" + port + "/" + dbName + "?user=" + user + "&password=" + password;
	}


	@Override
	protected ResultIterator executeSelect(String resultId, String query, LinkedHashMap<String, Binding> bindings,
			Map<String, String> values) {
		Connection connection;
		try {
			connection = DriverManager
					.getConnection(getConnectionString(host, port, dbName, user, password));
			PreparedStatement pstmt = connection.prepareStatement(query);
			return executeSelect(resultId, pstmt, bindings, values);
			
		} catch (SQLException e) {
			throw new RuntimeException(e);
		} 
	}
	
	private ResultIterator executeSelect(String resultId, PreparedStatement pstmt, LinkedHashMap<String, Binding> bindings,
			Map<String, String> values) {
		if (values.size() == bindings.size()) {
			List<String> lst = new ArrayList<String>();
			for (String key : bindings.keySet()) {
				lst.add(values.get(key));
			}
			return performSelect(pstmt, lst); 
		}
		else {
			List<ResultIterator> lst = new ArrayList<>();
			String var = bindings.keySet().iterator().next();
			Binding binding = bindings.get(var);
			ResultIterator results =  store.getResults(binding.getReference());
			results.beforeFirst();
			while (results.hasNextResult()) {
				results.nextResult();
				String value = (binding.getAttribute().equals("@id"))? results.getCurrentId(binding.getType()) : (String) results.getCurrentField(binding.getType(), binding.getAttribute());
				values.put(var, value);
				lst.add(executeSelect(resultId, pstmt, bindings, values));
			}
			return new AggregatedResultIterator(lst);
		}
	}

}
