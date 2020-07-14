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

package nl.cwi.swat.typhonql;

import nl.cwi.swat.typhonql.client.DatabaseInfo;

public class ConnectionInfo {
	private final String polystoreId;
	private final DatabaseInfo databaseInfo;
	
	public ConnectionInfo(String polystoreId, String host, int port, String dbName, String dbms, String user,
			String password) {
		this(polystoreId, new DatabaseInfo(host, port, dbName, dbms, "", user, password));
	}
	
	public ConnectionInfo(String polystoreId, DatabaseInfo databaseInfo) {
		this.polystoreId = polystoreId;
		this.databaseInfo = databaseInfo;
	}
	
	public String getPolystoreId() {
		return polystoreId;
	}

	public DatabaseInfo getDatabaseInfo() {
		return databaseInfo;
	}	
}
