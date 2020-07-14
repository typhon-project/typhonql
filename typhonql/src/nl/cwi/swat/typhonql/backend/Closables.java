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

import java.io.Closeable;

public class Closables {
	
	@SuppressWarnings("unchecked")
	public static <T extends Exception> void autoCloseAll(Iterable<? extends AutoCloseable> all, Class<T> exceptionType) throws T {
		T firstException = null;
		Exception unexpected = null;
		for (AutoCloseable ses : all) {
			try {
				ses.close();
			} catch (Exception e) {
				if (exceptionType.isInstance(e)) {
                    if (firstException == null) {
                        firstException = (T)e;
                    }
				}
				else if (unexpected == null) {
					unexpected = e;
				}
			}
		}
		if (firstException != null) {
			throw firstException;
		}
		if (unexpected != null) {
			throw new RuntimeException("Unexpected exception thrown", unexpected);
			
		}
	}

	public static <T extends Exception> void closeAll(Iterable<? extends Closeable> all, Class<T> exceptionType) throws T {
		T firstException = null;
		Exception unexpected = null;
		for (AutoCloseable ses : all) {
			try {
				ses.close();
			} catch (Exception e) {
				if (exceptionType.isInstance(e)) {
                    if (firstException == null) {
                        firstException = (T)e;
                    }
				}
				else if (unexpected == null) {
					unexpected = e;
				}
			}
		}
		if (firstException != null) {
			throw firstException;
		}
		if (unexpected != null) {
			throw new RuntimeException("Unexpected exception thrown", unexpected);
			
		}
	}
}
