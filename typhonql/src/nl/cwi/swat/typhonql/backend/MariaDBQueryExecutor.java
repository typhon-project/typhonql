package nl.cwi.swat.typhonql.backend;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public class MariaDBQueryExecutor extends QueryExecutor {
	
	private PreparedStatement pstmt;
	
	public MariaDBQueryExecutor(ResultStore store,  String query, Map<String, Binding> bindings, String connectionString) {
		super(store, query, bindings);
		try {
			Connection connection = DriverManager
					.getConnection(connectionString);
			pstmt = connection.prepareStatement(query);
		} catch (SQLException e) {
			throw new RuntimeException(e);
		} 
	}

	@Override
	protected ResultIterator performSelect(Map<String, String> values) {
		List<String> lst = new ArrayList<String>();
		for (String key : values.keySet()) {
			lst.add(values.get(key));
		}
		try {
			for (int i = 0 ; i < values.size() ; i++) {
				pstmt.setString(i + 1, lst.get(i));
			}
			ResultSet rs = pstmt.executeQuery(); 
			return new SQLResultIterator(rs);

		} catch (SQLException e1) {
			throw new RuntimeException(e1);
		}
	}

}
