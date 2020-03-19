package nl.cwi.swat.typhonql.backend;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.apache.commons.lang3.StringUtils;
import org.apache.commons.text.StringSubstitutor;

import nl.cwi.swat.typhonql.backend.rascal.Path;

public class MariaDBQueryExecutor extends QueryExecutor {
	
	private PreparedStatement pstmt;
	private List<String> vars = new ArrayList<String>();
	
	public MariaDBQueryExecutor(ResultStore store, List<Consumer<List<Record>>> script, Map<String, String> uuids, List<Path> signature, String query, Map<String, Binding> bindings, String connectionString) {
		super(store, script, uuids, bindings, signature);
		System.out.println(query);
		Pattern pat =  Pattern.compile("\\$\\{(\\w*?)\\}");
		Matcher m = pat.matcher(query);
		Map<String, String> map = new HashMap<String, String>();
		while (m.find()) {
			vars.add(m.group(1));
			map.put(m.group(1), "?");
		}	
		
		StringSubstitutor sub = new StringSubstitutor(map);
		String jdbcQuery = sub.replace(query);
		try {
			Connection connection = DriverManager
					.getConnection(connectionString);
			pstmt = connection.prepareStatement(jdbcQuery);
		} catch (SQLException e) {
			throw new RuntimeException(e);
		} 
	}

	@Override
	protected ResultIterator performSelect(Map<String, String> values) {
		try {
			int i = 1;
			for (String varName : vars) {
				Object decoded = decode(values.get(varName));
				if (decoded instanceof String)
					pstmt.setString(i, (String) decoded);
				else if (decoded instanceof Integer)
					pstmt.setInt(i, (Integer) decoded);
				else if (decoded instanceof Boolean)
					pstmt.setBoolean(i, (Boolean) decoded);
				i++;
			}
			ResultSet rs = pstmt.executeQuery(); 
			return new MariaDBIterator(rs);

		} catch (SQLException e1) {
			throw new RuntimeException(e1);
		}
	}
	
	private Object decode(String v) {
		if (v.startsWith("\"")) {
			return v.substring(1, v.length()-1);
		}
		else if (StringUtils.isNumeric(v)) {
			return Integer.parseInt(v);
		}
		throw new RuntimeException("Not known how to decode: " + v);
	}

	public static void main(String[] args) {
		String query = "select p.`Product.@id` as `p.Product.@id`, p.`Product.name` as `p.Product.name`, p.`Product.description` as `p.Product.description` from Product p where p.`Product.@id` = ?";
		String connectionString="jdbc:mariadb://localhost:3306/Inventory?user=root&password=example";
		try {
			Connection connection = DriverManager
					.getConnection(connectionString);
			PreparedStatement pstmt = connection.prepareStatement(query);
			pstmt.setString(1, "\"27cb16ca-c0df-4d59-b0b2-8a1a0c47a303\"");
			ResultSet rs = pstmt.executeQuery();
			System.out.println("");
		} catch (SQLException e) {
			throw new RuntimeException(e);
		} 

	
		
	}
}


