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

package nl.cwi.swat.typhonql.client;

public class DatabaseInfo {
	
	private final String host; 
	private final int port; 
	private final String dbName; 
	private final String dbms; 
	private final String user; 
	private final String password;
	
	public DatabaseInfo(String host, int port, String dbName, String dbms, String dbType, String user,
			String password) {
		// we ignore dbType, even though it is send to us from API
		this.host = host;
		this.port = port;
		this.dbName = dbName;
		this.dbms = dbms;
		this.user = user;
		this.password = password;
	}

	
	public String getHost() {
		return host;
	}
	
	public int getPort() {
		return port;
	}
	
	public String getDbName() {
		return dbName;
	}
	
	public String getDbms() {
		return dbms;
	}
	
	public String getUser() {
		return user;
	}
	
	public String getPassword() {
		return password;
	}


	@Override
	public String toString() {
		return "DatabaseInfo [host=" + host + ", port=" + port + ", dbName=" + dbName +
			   ", dbms=" + dbms + ", user=" + user + ", password=" + password + "]";
	}
	
	
}
