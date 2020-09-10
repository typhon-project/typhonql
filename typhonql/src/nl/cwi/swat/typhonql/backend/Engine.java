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

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Consumer;
import java.util.regex.Pattern;

public abstract class Engine {
	protected final ResultStore store;
	protected final Map<String, UUID> uuids;
	protected final List<Consumer<List<Record>>> script;
	protected static final Pattern QL_PARAMS = Pattern.compile("\\$\\{([\\w\\-]*?)\\}");

	public Engine(ResultStore store, List<Consumer<List<Record>>> script, Map<String, UUID> uuids) {
		this.store = store;
		this.script = script;
		this.uuids = uuids;
	}
	
}
