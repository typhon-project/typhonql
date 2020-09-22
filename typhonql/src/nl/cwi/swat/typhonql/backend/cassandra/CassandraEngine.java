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

package nl.cwi.swat.typhonql.backend.cassandra;

import java.time.Duration;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.UUID;
import java.util.function.Consumer;
import java.util.function.Supplier;
import java.util.regex.Matcher;
import java.util.stream.Collectors;

import org.locationtech.jts.geom.Geometry;

import com.datastax.oss.driver.api.core.CqlSession;
import com.datastax.oss.driver.api.core.cql.BatchStatement;
import com.datastax.oss.driver.api.core.cql.BatchStatementBuilder;
import com.datastax.oss.driver.api.core.cql.BatchType;
import com.datastax.oss.driver.api.core.cql.PreparedStatement;
import com.datastax.oss.driver.api.core.cql.SimpleStatement;

import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.Engine;
import nl.cwi.swat.typhonql.backend.QueryExecutor;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultIterator;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.UpdateExecutor;
import nl.cwi.swat.typhonql.backend.rascal.Path;
import nl.cwi.swat.typhonql.backend.rascal.TyphonSessionState;

public class CassandraEngine extends Engine {
	

	private final Map<String, DelayedPreparedStatement> preparedQueries = new HashMap<>();

	public CassandraEngine(ResultStore store, TyphonSessionState state, List<Consumer<List<Record>>> script, Map<String, UUID> uuids) {
		super(store, state, script, uuids);
	}

	public void executeSelect(String resultId, String query, Map<String, Binding> bindings, List<Path> signature, Supplier<CqlSession> connection) {
		new QueryExecutor(store, script, uuids, bindings, signature, () -> "Cassandra query: " + query) {
			@Override
			protected ResultIterator performSelect(Map<String, Object> values) {
				return new CassandraIterator(connection.get().execute(compileQuery(query, values, connection, false)));
			}
		}.scheduleSelect(resultId);
	}
	

	
	public void executeUpdate(String query, Map<String, Binding> bindings, Supplier<CqlSession> connection) {
		new UpdateExecutor(store, script, uuids, bindings, () -> "Cassandra update: " + query) {
			@Override
			protected void performUpdate(Map<String, Object> values) {
				SimpleStatement stm = compileQuery(query, values, connection, true);
				if (stm != null) {
					connection.get().execute(stm);
				}
			}
		}.scheduleUpdate();
	}

    private SimpleStatement compileQuery(String query, Map<String, Object> values, Supplier<CqlSession> connection, boolean delayable) {
        if (delayable && store.hasExternalArguments()) {
            DelayedPreparedStatement prepared = preparedQueries.get(query);
            if (prepared == null) {
                List<String> args = new ArrayList<>(1);
                Matcher m = QL_PARAMS.matcher(query);
                StringBuffer replacedQuery = new StringBuffer();
                while (m.find()) {
                    m.appendReplacement(replacedQuery, "?");
                    args.add(m.group(1));
                }
                m.appendTail(replacedQuery);
            	PreparedStatement stm = connection.get().prepare(replacedQuery.toString());
            	DelayedPreparedStatement newPrepared = prepared = new DelayedPreparedStatement(stm, args);
            	preparedQueries.put(query, prepared);
            	state.addDelayedTask(() -> newPrepared.execute(connection));
            }
            prepared.bind(encode(values));
            return null;
        }
        else {
            Matcher m = QL_PARAMS.matcher(query);
            StringBuffer replacedQuery = new StringBuffer();
            while (m.find()) {
                m.appendReplacement(replacedQuery, ":" + m.group(1));
            }
            m.appendTail(replacedQuery);
            return SimpleStatement.newInstance(replacedQuery.toString(), encode(values)).setTimeout(Duration.ofSeconds(30));
        }
    }
	
	private Map<String, Object> encode(Map<String, Object> values) {
		return values.entrySet().stream()
				.collect(Collectors.toMap(
						Entry::getKey, 
						e -> encode(e.getValue())
					)
				);
	}

	private Object encode(Object value) {
		if (value instanceof Geometry) {
			throw new RuntimeException("Geo values not supported on Cassandra");
		}
		// other java values are just fine as they are
		return value;
	}

	private static final class DelayedPreparedStatement {
		private final BatchStatementBuilder builder = BatchStatement.builder(BatchType.UNLOGGED);
		private final PreparedStatement stm;
		private final List<String> argBinds;
		
		public DelayedPreparedStatement(PreparedStatement stm, List<String> argBinds) {
			this.stm = stm;
			this.argBinds = argBinds;
		}
		
		public void bind(Map<String, Object> values) {
			Object[] args = new Object[argBinds.size()];
			for (int i = 0; i < args.length; i++) {
				args[i] = values.get(argBinds.get(i));
			}
			builder.addStatement(stm.bind(args));
		}

		
		public void execute(Supplier<CqlSession> session) {
			session.get().execute(builder.build());
			builder.clearStatements();
		}


	}
}
