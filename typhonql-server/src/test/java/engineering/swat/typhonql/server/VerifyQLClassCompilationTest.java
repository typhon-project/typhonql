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

package engineering.swat.typhonql.server;
import static org.junit.jupiter.api.Assertions.*;
import java.lang.reflect.Constructor;
import org.junit.jupiter.api.Test;
import nl.cwi.swat.typhonql.client.DatabaseInfo;

public class VerifyQLClassCompilationTest {

	@Test
	void checkArgNamesCompiled() {
		Constructor<?>[] cons = DatabaseInfo.class.getConstructors();
		for (Constructor<?> c : cons) {
			if (c.getParameterCount() > 0) {
				assertFalse(c.getParameters()[0].getName().equals("arg0"), "Make sure ql is compiled with parameter names");
			}
		}
		
	}

}
