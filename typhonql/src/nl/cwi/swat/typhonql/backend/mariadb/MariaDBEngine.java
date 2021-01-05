/********************************************************************************
* Copyright (c) 2018-2020 CWI & Swat.engineering 
*
* This program and the accompanying materials are made available under the
* terms of the Eclipse Public License 2.0 which is available at
* http://www.eclipse.org/legal/epl-2.0.
*
* This Source Code may also be made available under the following Secondary
* Licenses when the conditions for such availability set forth in the Eclipse
* Public License, v. 2.0 are satisfied: GNU General Public License, version 2
* with the GNU Classpath Exception which is
* available at https://www.gnu.org/software/classpath/license.html.
*
* SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0
********************************************************************************/

package nl.cwi.swat.typhonql.backend.mariadb;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Consumer;
import java.util.function.Supplier;
import java.util.regex.Matcher;

import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.io.WKBWriter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import lang.typhonql.util.MakeUUID;
import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.Engine;
import nl.cwi.swat.typhonql.backend.QueryExecutor;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultIterator;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.UpdateExecutor;
import nl.cwi.swat.typhonql.backend.rascal.Path;
import nl.cwi.swat.typhonql.backend.rascal.TyphonSessionState;

public class MariaDBEngine extends Engine {
	private static final Logger logger = LoggerFactory.getLogger(MariaDBEngine.class);
	private final Supplier<Connection> connection;
	private final Map<String, PreparedStatementArgs> preparedQueries;

	public MariaDBEngine(ResultStore store, TyphonSessionState state, List<Consumer<List<Record>>> script, Map<String, UUID> uuids, Supplier<Connection> sqlConnection) {
		super(store, state, script, uuids);
		this.connection = sqlConnection;
		preparedQueries = state.getFromCache(MariaDBEngine.class.getName(), s -> new HashMap<String, PreparedStatementArgs>());
	}

	private PreparedStatement prepareQuery(String query, List<String> vars, Set<String> blobs, Set<String> geometries) throws SQLException {
		Matcher m = QL_PARAMS.matcher(query);
		StringBuffer result = new StringBuffer(query.length());
		while (m.find()) {
			String param = m.group(1);
			if (geometries.contains(param)) {
				m.appendReplacement(result, "GeomFromWKB(?, 4326)");
			}
			else {
                m.appendReplacement(result, "?");
                if (param.startsWith("blob-")) {
                    param = param.substring("blob-".length());
                    blobs.add(param);
                }
			}
            vars.add(param);
		}
		m.appendTail(result);
        return connection.get().prepareStatement(result.toString());
	}

    private PreparedStatement prepareAndBind(String query, Map<String, Object> values, boolean delayable)
            throws SQLException {
    	PreparedStatementArgs preparedQuery = preparedQueries.get(query);
    	if (preparedQuery == null) {
            List<String> vars = new ArrayList<>();
            Set<String> blobs = new HashSet<>();
            Set<String> geometries = new HashSet<>();
            values.forEach((k, v) -> {
                if (v instanceof Geometry) {
                    geometries.add(k);
                }
            });
            PreparedStatement stm = prepareQuery(query, vars, blobs, geometries);
            preparedQuery = new PreparedStatementArgs(stm, vars, blobs);
            preparedQueries.put(query, preparedQuery);
    	}
        int i = 1;
        for (String varName : preparedQuery.variables) {
            Object value = values.get(varName);
            if (value == null && preparedQuery.blobs.contains(varName)) {
                preparedQuery.statement.setBlob(i, store.getBlob(varName));
            }
            else if (value instanceof Geometry) {
            	preparedQuery.statement.setBytes(i, new WKBWriter().write((Geometry) value));
            }
            else if (value instanceof UUID) {
            	preparedQuery.statement.setBytes(i, MakeUUID.uuidToBytes((UUID)value));
            }
            else if (value instanceof Instant) {
            	preparedQuery.statement.setObject(i, ((Instant) value).atOffset(ZoneOffset.UTC).toLocalDateTime());
            }
            else {
                // TODO: what to do with NULL?
                // other classes jdbc can take care of itself
                preparedQuery.statement.setObject(i, value);
            }
            i++;
        }
        if (delayable && store.hasExternalArguments()) {
        	preparedQuery.statement.addBatch();
        	if (!preparedQuery.alreadyScheduled) {
        		PreparedStatement stm = preparedQuery.statement;
        		state.addDelayedTask(() -> {
					try {
						logger.debug("Executing: {}", stm);
						stm.executeBatch();
					} catch (SQLException e) {
						throw new RuntimeException(e);
					}
				});
        		preparedQuery.alreadyScheduled = true;
        	}
        	return null;
        }
        return preparedQuery.statement;
    }

	public void executeSelect(String resultId, String query, List<Path> signature) {
		executeSelect(resultId, query, new HashMap<String, Binding>(), signature);
	}



	public void executeSelect(String resultId, String query, Map<String, Binding> bindings, List<Path> signature) {
		new QueryExecutor(store, script, uuids, bindings, signature, () -> "Maria query: " + query) {
			@Override
			protected ResultIterator performSelect(Map<String, Object> values) {
				try {
					return new MariaDBIterator(prepareAndBind(query, values, false).executeQuery());
				} catch (SQLException e1) {
					throw new RuntimeException(e1);
				}
			}

		}.scheduleSelect(resultId); 
	}


	public void executeUpdate(String query, Map<String, Binding> bindings) {
		new UpdateExecutor(store, script, uuids, bindings, () -> "Maria update: " + query) {

            @Override
            protected void performUpdate(Map<String, Object> values) {
                try {
					PreparedStatement result = prepareAndBind(query, values, true);
					if (result != null) {
						// we aren't scheduled for later
						result.executeUpdate();
					}
                } catch (SQLException e1) {
                    throw new RuntimeException(e1);
                }
            }
		}.scheduleUpdate();
	}
	
	private static class PreparedStatementArgs {
		public final PreparedStatement statement;
		public final List<String> variables;
		public final Set<String> blobs;
		public boolean alreadyScheduled = false;
		public PreparedStatementArgs(PreparedStatement statement, List<String> variables, Set<String> blobs) {
			this.statement = statement;
			this.variables = variables;
			this.blobs = blobs;
		}
	}
}
