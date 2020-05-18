package nl.cwi.swat.typhonql.backend.mariadb;

import java.sql.Connection;
import java.sql.PreparedStatement;
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
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.io.WKBWriter;
import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.Engine;
import nl.cwi.swat.typhonql.backend.QueryExecutor;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultIterator;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.UpdateExecutor;
import nl.cwi.swat.typhonql.backend.rascal.Path;

public class MariaDBEngine extends Engine {

	private final Connection connection;
	private static final Pattern QL_PARAMS = Pattern.compile("\\$\\{(\\w*?)\\}");

	public MariaDBEngine(ResultStore store, List<Consumer<List<Record>>> script, List<Runnable> updates, Map<String, String> uuids, Connection sqlConnection) {
		super(store, script, updates, uuids);
		this.connection = sqlConnection;
	}

	private PreparedStatement prepareQuery(String query, Connection connection, List<String> vars) throws SQLException {
		Matcher m = QL_PARAMS.matcher(query);
		Map<String, String> map = new HashMap<String, String>();
		while (m.find()) {
			vars.add(m.group(1));
			map.put(m.group(1), "?");
		}	
		
		StringSubstitutor sub = new StringSubstitutor(map);
		String jdbcQuery = sub.replace(query);
        return connection.prepareStatement(jdbcQuery);
	}

	public void executeSelect(String resultId, String query, List<Path> signature) {
		executeSelect(resultId, query, new HashMap<String, Binding>(), signature);
	}

	public void executeSelect(String resultId, String query, Map<String, Binding> bindings, List<Path> signature) {
		new QueryExecutor(store, script, uuids, bindings, signature) {
			@Override
			protected ResultIterator performSelect(Map<String, Object> values) {
				try {
                    List<String> vars = new ArrayList<>();
                    PreparedStatement stm = prepareQuery(query, connection, vars);
					int i = 1;
					for (String varName : vars) {
						Object value = values.get(varName);
						if (value instanceof Geometry) {
							stm.setBytes(i, new WKBWriter().write((Geometry) value));
						}
						else {
							// TODO: what to do with NULL?
							// other classes jdbc can take care of itself
							stm.setObject(i, value);
						}
						i++;
					}
					return new MariaDBIterator(stm.executeQuery());
				} catch (SQLException e1) {
					throw new RuntimeException(e1);
				}
			}
		}.executeSelect(resultId);
	}

	public void executeUpdate(String query, Map<String, Binding> bindings) {
		new UpdateExecutor(store, updates, uuids, bindings) {
			
            @Override
            protected void performUpdate(Map<String, String> values) {
                try {
                    List<String> vars = new ArrayList<>();
                    PreparedStatement stm = prepareQuery(query, connection, vars);
                    int i = 1;
                    for (String varName : vars) {
                        Object decoded = decode(values.get(varName));
                        if (decoded instanceof String)
                            stm.setString(i, (String) decoded);
                        else if (decoded instanceof Integer)
                            stm.setInt(i, (Integer) decoded);
                        else if (decoded instanceof Boolean)
                            stm.setBoolean(i, (Boolean) decoded);
                        i++;
                    }
                    stm.executeUpdate();
                } catch (SQLException e1) {
                    throw new RuntimeException(e1);
                }
                
            }
		}.executeUpdate();
	}

	private static Object decode(String v) {
		if (v.startsWith("\"")) {
			return v.substring(1, v.length()-1);
		}
		else if (StringUtils.isNumeric(v)) {
			return Integer.parseInt(v);
		}
		throw new RuntimeException("Not known how to decode: " + v);
	}
}
