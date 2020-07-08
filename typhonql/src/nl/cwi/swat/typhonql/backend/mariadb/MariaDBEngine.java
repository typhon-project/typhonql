package nl.cwi.swat.typhonql.backend.mariadb;

import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Consumer;
import java.util.function.Supplier;
import java.util.regex.Matcher;

import org.apache.commons.text.StringSubstitutor;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.io.WKBWriter;
import org.rascalmpl.eclipse.util.ThreadSafeImpulseConsole;

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

	public MariaDBEngine(ResultStore store, List<Consumer<List<Record>>> script, List<Runnable> updates, Map<String, String> uuids, Supplier<Connection> sqlConnection) {
		super(store, script, updates, uuids);
		this.connection = sqlConnection;
	}

	private PreparedStatement prepareQuery(String query, List<String> vars, Set<String> blobs) throws SQLException {
		Matcher m = QL_PARAMS.matcher(query);
		StringBuffer result = new StringBuffer(query.length());
		while (m.find()) {
            m.appendReplacement(result, "?");
			String param = m.group(1);
            vars.add(param);
			log("Match: " + param + " details: " + m + "\n");
            if (param.startsWith("blob-")) {
            	blobs.add(param.substring("blob-".length()));
            }
		}
		m.appendTail(result);
		String jdbcQuery = result.toString();
		log("query: " + jdbcQuery + "\n");
        return connection.get().prepareStatement(jdbcQuery);
	}
	
	private static void log(String msg) {
		try {
			ThreadSafeImpulseConsole.INSTANCE.getWriter().append(msg);
		} catch (IOException e) {
		}
	}

    private PreparedStatement prepareAndBind(String query, Map<String, Object> values)
            throws SQLException {
        List<String> vars = new ArrayList<>();
        Set<String> blobs = new HashSet<>();
        PreparedStatement stm = prepareQuery(query, vars, blobs);
        int i = 1;
        for (String varName : vars) {
            Object value = values.get(varName);
            if (value == null && blobs.contains(varName)) {
                stm.setBlob(i, store.getBlob(varName));
            }
            else if (value instanceof Geometry) {
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
