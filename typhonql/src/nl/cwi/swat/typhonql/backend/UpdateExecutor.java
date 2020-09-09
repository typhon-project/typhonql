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

import java.io.IOException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Supplier;

import org.rascalmpl.eclipse.util.ThreadSafeImpulseConsole;

public abstract class UpdateExecutor {
	
	
	private ResultStore store;
	private List<Runnable> updates;
	private Map<String, Binding> bindings;
	private Map<String, UUID> uuids;
	private final Supplier<String> toString;
	
	public UpdateExecutor(ResultStore store, List<Runnable> updates, Map<String, UUID> uuids, Map<String, Binding> bindings, Supplier<String> toString) {
		this.store = store;
		this.updates = updates;
		this.bindings = bindings;
		this.uuids = uuids;
		this.toString = toString;
	}
	
	@Override
	public String toString() {
		return toString.get();
	}
	
	public void executeUpdate() {
		executeUpdate(new HashMap<>());
	}
	
	private void executeUpdate(Map<String, Object> values) {
		updates.add(() -> {  executeUpdateOperation(values); });
		log("Added: " + toString() + "as: " + System.identityHashCode(updates.get(updates.size() - 1)) + "\n");
	}

	private static void log(String msg) {
		try {
			ThreadSafeImpulseConsole.INSTANCE.getWriter().append(msg);
		} catch (IOException e) {
		}
	}

	protected abstract void performUpdate(Map<String, Object> values);
	
	private void executeUpdateOperation(Map<String, Object> values) {
		log("Executing: " + toString() + "\n");
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
