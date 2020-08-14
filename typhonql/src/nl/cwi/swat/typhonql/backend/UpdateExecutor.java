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

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.regex.Matcher;
import java.util.Optional;
import java.util.UUID;

public abstract class UpdateExecutor {

	private String query;
	private ResultStore store;
	private List<Runnable> updates;
	private Map<String, Binding> bindings;
	private Map<String, List<UUID>> uuids;
	private Optional<MultipleBindings> mBindings;

	public UpdateExecutor(String query, ResultStore store, List<Runnable> updates, Map<String, List<UUID>> uuids,
			Map<String, Binding> bindings) {
		this(query, store, updates, uuids, bindings, Optional.empty());
	}

	public UpdateExecutor(String query, ResultStore store, List<Runnable> updates, Map<String, List<UUID>> uuids,
			Map<String, Binding> bindings, Optional<MultipleBindings> mBindings) {
		this.query = query;
		this.store = store;
		this.updates = updates;
		this.bindings = bindings;
		this.uuids = cloneMap(uuids);
		this.mBindings = mBindings;
	}

	public void executeUpdate() {
		Matcher m = Engine.QL_PARAMS.matcher(query);
		List<String> allVars = new ArrayList<String>();
		while (m.find()) {
			String param = m.group(1);
			allVars.add(param);
		}
		if (mBindings.isPresent()) {
			MultipleBindings mbs = mBindings.get();
			for (List<String> row : mbs.getValues()) {
				Map<String, Object> values = toObjectRepresentation(row, mbs.getVarNames(), mbs.getTypesMap(), allVars);
				executeUpdateOperation(values);
			}
		}
		else
			executeUpdateOperation(new HashMap<String, Object>());
	}

	private Map<String, List<UUID>> cloneMap(Map<String, List<UUID>> uuids) {
		 Map<String, List<UUID>>  map = new HashMap<>();
		 for (Entry<String, List<UUID>> e : uuids.entrySet()) {
			 map.put(e.getKey(), new ArrayList<UUID>(e.getValue()));
		 }
		 return map;
	}

	protected abstract void performUpdate(Map<String, Object> values);

	private void executeUpdateOperation(Map<String, Object> values) {
		if (values.size() == (bindings.size() + (mBindings.isPresent()?mBindings.get().getVarNames().size():0))) {
			performUpdate(values);
		} else {
			String var = bindings.keySet().iterator().next();
			Binding binding = bindings.get(var);
			if (binding instanceof Field) {
				Field field = (Field) binding;
				ResultIterator results = store.getResults(field.getReference());
				if (results == null) {
					throw new RuntimeException(
							"Results was null for field " + field.toString() + " and store " + store);
				}

				results.beforeFirst();

				while (results.hasNextResult()) {
					results.nextResult();
					Object value = (field.getAttribute().equals("@id"))
							? results.getCurrentId(field.getLabel(), field.getType())
							: results.getCurrentField(field.getLabel(), field.getType(), field.getAttribute());
					values.put(var, value);
					executeUpdateOperation(values);
				}
			} else {
				GeneratedIdentifier id = (GeneratedIdentifier) binding;
				UUID uuid = uuids.get(id.getName()).remove(0);
				values.put(var, uuid);
				executeUpdateOperation(values);
			}

		}
	}

	private Map<String, Object> toObjectRepresentation(List<String> row, List<String> vars,
			Map<String, String> types, List<String> varsToKeep) {
		Map<String, Object> vs = new HashMap<String, Object>();
		for (int i = 0; i < vars.size(); i++) {
			if (varsToKeep.contains(vars.get(i)))
				vs.put(vars.get(i), toObjectRepresentation(types.get(vars.get(i)), row.get(i)));
		}
		return vs;

	}
	
	private Object toObjectRepresentation(String type, String val) {
		switch(type) {
		case "string": return val;
		case "int": return Integer.parseInt(val);
		case "uuid": return UUID.fromString(val);
		default: return val;
		}
	}

}
