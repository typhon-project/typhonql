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

package nl.cwi.swat.typhonql.backend;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Consumer;
import java.util.function.Supplier;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public abstract class UpdateExecutor {

	private static final Logger logger = LoggerFactory.getLogger(UpdateExecutor.class);
	private final ResultStore store;
	private final Map<String, Binding> bindings;
	private final Map<String, UUID> uuids;
	private final Supplier<String> toString;
	private final List<Consumer<List<Record>>> script;
	
	public UpdateExecutor(ResultStore store, List<Consumer<List<Record>>> script, Map<String, UUID> uuids, Map<String, Binding> bindings, Supplier<String> toString) {
		this.store = store;
		this.script = script;
		this.bindings = bindings;
		this.uuids = uuids;
		this.toString = toString;
	}
	
	@Override
	public String toString() {
		return toString.get();
	}
	
	public void scheduleUpdate() {
		scheduleUpdate(new HashMap<>());
	}
	
	private void scheduleUpdate(Map<String, Object> values) {
		int nxt = script.size() + 1;
		script.add(lr -> {
            executeUpdateOperation(values);
            if (script.size() > nxt) {
                script.get(nxt).accept(lr);
            }
		});
	}

	protected abstract void performUpdate(Map<String, Object> values);
	
	private void executeUpdateOperation(Map<String, Object> values) {
		if (logger.isDebugEnabled()) {
			logger.debug("Running update step: " + toString.get());
		}
		logger.trace("Input arguments: {}", values);

		if (values.size() == bindings.size()) {
			if (store.hasExternalArguments()) {
				values.putAll(store.getCurrentExternalArgumentsRow());
			}
			performUpdate(values); 
		}
		else {
			String var = bindings.keySet().iterator().next();
			Binding binding = bindings.get(var);
			if (binding instanceof Field) {
				Field field = (Field) binding;
				ResultIterator results =  store.getResults(field.getReference());
				if (results == null) {
					throw new RuntimeException("Results was null for field " + field.toString() + " and store " + store);
				}
				
				results.beforeFirst();
				
				while (results.hasNextResult()) {
					results.nextResult();
					Object value = (field.getAttribute().equals("@id"))? results.getCurrentId(field.getLabel(), field.getType()) : results.getCurrentField(field.getLabel(), field.getType(), field.getAttribute());
					values.put(var, value);
					executeUpdateOperation(values);
				}
			}
			else {
				GeneratedIdentifier id = (GeneratedIdentifier) binding;
				values.put(var, uuids.get(id.getName()));
				executeUpdateOperation(values);
			}
			
		}
	}
}
