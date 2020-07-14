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

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import nl.cwi.swat.typhonql.backend.rascal.Path;

public interface ResultIterator {
	void nextResult();
	boolean hasNextResult();
	UUID getCurrentId(String label, String type);
	Object getCurrentField(String label, String type, String name);
	void beforeFirst();
	default Record buildRecord(List<Path> signature) {
		Map<Field, Object> vs = new HashMap<>();
		if (signature.isEmpty())
			return new Record(vs);
		Path first = signature.get(0);
		Path id = new Path(first.getDbName(), first.getVar(), first.getEntityType(), new String[] { "@id" });
		for (Path p : Stream.concat(signature.stream(), Stream.of(id)).collect(Collectors.toList())) {
			Field f = toField(p);
			Object v = (f.getAttribute().equals("@id")) 
					? getCurrentId(f.getLabel(), f.getType())
					: getCurrentField(f.getLabel(), f.getType(), f.getAttribute());
			vs.put(f, v);
		}
		return new Record(vs);
	}
	
	default Field toField(Path p) {
		return new Field(p.getDbName(), p.getVar(), p.getEntityType(), p.getSelectors()[0]);
	}
}
