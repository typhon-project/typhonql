package nl.cwi.swat.typhonql.backend.mariadb;

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
import org.apache.commons.text.StringSubstitutor;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.io.WKBWriter;
import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.QueryExecutor;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultIterator;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.rascal.Path;

public class MariaDBQueryExecutor extends QueryExecutor {
	
	private PreparedStatement pstmt;
	private List<String> vars = new ArrayList<String>();
	
	public MariaDBQueryExecutor(ResultStore store, List<Consumer<List<Record>>> script, Map<String, String> uuids, List<Path> signature, String query, Map<String, Binding> bindings, Connection connection) {
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
			pstmt = connection.prepareStatement(jdbcQuery);
		} catch (SQLException e) {
			throw new RuntimeException(e);
		} 
	}

	@Override
	protected ResultIterator performSelect(Map<String, Object> values) {
		try {
			int i = 1;
			for (String varName : vars) {
				Object value = values.get(varName);
				if (value instanceof Geometry) {
					pstmt.setBytes(i, new WKBWriter().write((Geometry) value));
				}
				else {
					// TODO: what to do with NULL?
					// other classes jdbc can take care of itself
					pstmt.setObject(i, value);
				}
				i++;
			}
			ResultSet rs = pstmt.executeQuery(); 
			return new MariaDBIterator(rs);

		} catch (SQLException e1) {
			throw new RuntimeException(e1);
		}
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


