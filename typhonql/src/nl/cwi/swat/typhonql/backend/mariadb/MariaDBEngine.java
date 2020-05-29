package nl.cwi.swat.typhonql.backend.mariadb;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import java.util.function.Supplier;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

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

	private final Supplier<Connection> connection;
	private static final Pattern QL_PARAMS = Pattern.compile("\\$\\{(\\w*?)\\}");

	public MariaDBEngine(ResultStore store, List<Consumer<List<Record>>> script, List<Runnable> updates, Map<String, String> uuids, Supplier<Connection> sqlConnection) {
		super(store, script, updates, uuids);
		this.connection = sqlConnection;
	}

	private PreparedStatement prepareQuery(String query, List<String> vars) throws SQLException {
		Matcher m = QL_PARAMS.matcher(query);
		Map<String, String> map = new HashMap<String, String>();
		while (m.find()) {
			vars.add(m.group(1));
			map.put(m.group(1), "?");
		}

		StringSubstitutor sub = new StringSubstitutor(map);
		String jdbcQuery = sub.replace(query);
        return connection.get().prepareStatement(jdbcQuery);
	}

    private PreparedStatement prepareAndBind(String query, Map<String, Object> values)
            throws SQLException {
        List<String> vars = new ArrayList<>();
        PreparedStatement stm = prepareQuery(query, vars);
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
        return stm;
    }

	public void executeSelect(String resultId, String query, List<Path> signature) {
		executeSelect(resultId, query, new HashMap<String, Binding>(), signature);
	}



	public void executeSelect(String resultId, String query, Map<String, Binding> bindings, List<Path> signature) {
		new QueryExecutor(store, script, uuids, bindings, signature) {
			@Override
			protected ResultIterator performSelect(Map<String, Object> values) {
				try {
					return new MariaDBIterator(prepareAndBind(query, values).executeQuery());
				} catch (SQLException e1) {
					throw new RuntimeException(e1);
				}
			}

		}.executeSelect(resultId);
	}


	public void executeUpdate(String query, Map<String, Binding> bindings) {
		new UpdateExecutor(store, updates, uuids, bindings) {

            @Override
            protected void performUpdate(Map<String, Object> values) {
                try {
					prepareAndBind(query, values).executeUpdate();
                } catch (SQLException e1) {
                    throw new RuntimeException(e1);
                }
            }
		}.executeUpdate();
	}
}
