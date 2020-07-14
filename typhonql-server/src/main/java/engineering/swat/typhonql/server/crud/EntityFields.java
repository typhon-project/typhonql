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

package engineering.swat.typhonql.server.crud;

import java.util.HashMap;
import java.util.Map;

public class EntityFields {
	private final Map<String, Object> fields;

	public EntityFields(Map<String, Object> fields) {
		this.fields = fields;
	}
	
	public EntityFields() {
		this(new HashMap<>());
	}

	public Map<String, Object> getFields() {
		return fields;
	}
	
}
