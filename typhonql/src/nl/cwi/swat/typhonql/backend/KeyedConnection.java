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

import java.util.Objects;
import nl.cwi.swat.typhonql.backend.rascal.ConnectionData;

public class KeyedConnection {
	
	private final String key;
	private final ConnectionData connection;
	
	public KeyedConnection(String key, ConnectionData connection) {
		this.key = key;
		this.connection = connection;
	}

	@Override
	public int hashCode() {
		return Objects.hash(connection, key);
	}

	@Override
	public boolean equals(Object obj) {
		if (this == obj) {
			return true;
		}
		if (obj instanceof KeyedConnection) {
			KeyedConnection other = (KeyedConnection) obj;
			return Objects.equals(connection, other.connection) && Objects.equals(key, other.key);
		}
		return false;
	}

	
}
