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

import java.util.Objects;
import nl.cwi.swat.typhonql.client.DatabaseInfo;

public class ConnectionData {
	private final String host;
	private final int port;
	private final String user;
	private final String password;
	
	public ConnectionData(DatabaseInfo from) {
		this(from.getHost(), from.getPort(), from.getUser(), from.getPassword());
	}

	public ConnectionData(String host, int port, String user, String password) {
		this.host = host;
		this.port = port;
		this.user = user;
		this.password = password;
	}

	public String getHost() {
		return host;
	}

	public int getPort() {
		return port;
	}

	public String getUser() {
		return user;
	}

	public String getPassword() {
		return password;
	}

	@Override
	public int hashCode() {
		return Objects.hash(host, password, port, user);
	}

	@Override
	public boolean equals(Object obj) {
		if (this == obj) {
			return true;
		}
		if (obj instanceof ConnectionData) {
			ConnectionData other = (ConnectionData) obj;
			return Objects.equals(host, other.host) && Objects.equals(password, other.password)
					&& port == other.port && Objects.equals(user, other.user);
		}
		return false;
	}
	
	
	

}
