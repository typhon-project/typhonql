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

import java.io.InputStream;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.function.Function;

public class ResultStore {

	private final Map<String, ResultIterator> store;
	private final Map<String, InputStream> blobMap;
	private final Optional<ExternalArguments> externalArguments;

	public ResultStore(Map<String, InputStream> blobMap, Optional<ExternalArguments> externalArguments) {
		store = new HashMap<String, ResultIterator>();
		this.blobMap = blobMap;
		this.externalArguments = externalArguments;
	}

	@Override
	public String toString() {
		return "RESULTSTORE(" + store.toString() + ")";
	}

	public ResultIterator getResults(String id) {
		return store.get(id);
	}

	public void put(String id, ResultIterator results) {
		store.put(id, results);
	}

	public void clear() {
		store.clear();
	}
	
	public InputStream getBlob(String key) {
		return blobMap.get(key);
	}
	
	public Map<String, Object> getCurrentExternalArgumentsRow() {
		return ensureExternalArguments(args -> args.getCurrentRow());
	}

	public boolean hasMoreExternalArguments() {
		return ensureExternalArguments(args -> args.hasNextRow());
	}

	private <T> T ensureExternalArguments(Function<ExternalArguments,T> f) {
		if (externalArguments.isPresent()) {
			return f.apply(externalArguments.get());
		}
		else
			throw new RuntimeException("No external arguments have been provided");
	}

	public boolean hasExternalArguments() {
		return externalArguments.isPresent();
	}
	
	public void nextExternalArguments() {
		assert(externalArguments.isPresent());
		externalArguments.get().next();
	}

}
