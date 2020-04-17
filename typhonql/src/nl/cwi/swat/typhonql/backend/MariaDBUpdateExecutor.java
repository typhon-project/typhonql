package nl.cwi.swat.typhonql.backend;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.apache.commons.lang3.StringUtils;
import org.apache.commons.text.StringSubstitutor;

public class MariaDBUpdateExecutor extends UpdateExecutor {
	
	private PreparedStatement pstmt;
	private List<String> vars = new ArrayList<String>();
	
	public MariaDBUpdateExecutor(ResultStore store, Map<String, String> uuids, String query, Map<String, Binding> bindings, Connection connection) {
		super(store, uuids, bindings);
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
			pstmt = connection.prepareStatement(jdbcQuery);
		} catch (SQLException e) {
			throw new RuntimeException(e);
		} 
	}

	@Override
	protected void performUpdate(Map<String, String> values) {
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
			pstmt.executeUpdate();

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


}


