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

import java.util.ArrayList;
import java.util.List;

import nl.cwi.swat.typhonql.backend.Closables;
import nl.cwi.swat.typhonql.client.JsonSerializableResult;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

public class TyphonSessionState implements AutoCloseable {
	
	private boolean finalized = false;
	private JsonSerializableResult result = null;

	private final List<AutoCloseable> operations = new ArrayList<>();


	@Override
	public void close() throws Exception {
        this.finalized = true;
        this.result = null;
        Closables.autoCloseAll(operations, Exception.class);
	}

	public JsonSerializableResult getResult() {
		return result;
	}

	public void setResult(JsonSerializableResult result) {
		this.result = result;
	}

	public boolean isFinalized() {
		return finalized;
	}
	
	public void addOpperations(AutoCloseable op) {
		operations.add(op);
	}
}
