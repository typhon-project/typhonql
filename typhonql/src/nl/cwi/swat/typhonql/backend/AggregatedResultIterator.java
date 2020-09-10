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
import java.util.UUID;

public class AggregatedResultIterator implements ResultIterator {
	
	private final List<ResultIterator> results;
	private int index = -1;

	public AggregatedResultIterator(List<ResultIterator> lst) {
		this.results = lst;
		beforeFirst();
	}

	@Override
	public void nextResult() {
		if (results.get(index).hasNextResult()) {
			results.get(index).nextResult();
		} else {
			index ++;
			results.get(index).nextResult();
		}
	}
	
	@Override
	public boolean hasNextResult() {
		return index < results.size() && hasNextResult(index);
	}

	private boolean hasNextResult(int i) {
		if (results.get(i).hasNextResult()) {
			return true;
		} else {
			if (i == results.size() -1) {
				return false;
			}
			else {
				return hasNextResult(i + 1);
			}
		}
	}

	@Override
	public UUID getCurrentId(String label, String type) {
		return results.get(index).getCurrentId(label, type);
	}

	@Override
	public Object getCurrentField(String label, String type, String name) {
		return results.get(index).getCurrentField(label, type, name);
	}

	@Override
	public void beforeFirst() {
		index = 0;
		for (ResultIterator iter : results) {
			iter.beforeFirst();
		}

	}
}
