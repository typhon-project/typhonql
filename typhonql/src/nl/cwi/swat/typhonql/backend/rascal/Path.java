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

package nl.cwi.swat.typhonql.backend.rascal;

import java.util.Arrays;

public class Path {
	private String dbName;
	private String var;
	private String entityType;
	private String[] selectors;
	
	public Path(String dbName, String var, String entityType, String[] selectors) {
		super();
		this.dbName = dbName;
		this.var = var;
		this.entityType = entityType;
		this.selectors = selectors;
	}
	
	public String getDbName() {
		return dbName;
	}
	public String getVar() {
		return var;
	}
	public String getEntityType() {
		return entityType;
	}
	public String[] getSelectors() {
		return selectors;
	}
	
	public boolean isRoot() {
		if (selectors == null)
			return true;
		else if (selectors.length == 0)
			return true;
		else 
			return false;
	}
	
	@Override
	public int hashCode() {
		return dbName.hashCode() * 3 + var.hashCode() * 7 + entityType.hashCode() * 11 + Arrays.deepHashCode(selectors) * 13;
	}
	
	
}
