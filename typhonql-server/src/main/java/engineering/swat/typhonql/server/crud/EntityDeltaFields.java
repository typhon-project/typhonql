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

import java.util.List;
import java.util.Map;

public class EntityDeltaFields {
	private Map<String, String> fieldsAndSimpleRelations;
	private Map<String, List<String>> set;
	private Map<String, List<String>> add;
	private Map<String, List<String>> remove;

	public EntityDeltaFields(Map<String, String> fieldsAndSimpleRelations, Map<String, List<String>> set,
			Map<String, List<String>> add, Map<String, List<String>> remove) {
		super();
		this.fieldsAndSimpleRelations = fieldsAndSimpleRelations;
		this.set = set;
		this.add = add;
		this.remove = remove;
	}

	public Map<String, String> getFieldsAndSimpleRelations() {
		return fieldsAndSimpleRelations;
	}

	public Map<String, List<String>> getSet() {
		return set;
	}

	public Map<String, List<String>> getAdd() {
		return add;
	}

	public Map<String, List<String>> getRemove() {
		return remove;
	}

}
