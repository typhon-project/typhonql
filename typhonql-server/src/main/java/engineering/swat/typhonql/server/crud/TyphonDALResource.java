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

package engineering.swat.typhonql.server.crud;

import java.io.IOException;
import java.io.StringReader;
import java.util.Map;
import java.util.stream.Collectors;

import javax.servlet.ServletContext;
import javax.ws.rs.core.Context;
import javax.ws.rs.core.HttpHeaders;

import engineering.swat.typhonql.server.QLRestServer;
import nl.cwi.swat.typhonql.client.XMIPolystoreConnection;

public abstract class TyphonDALResource {
	@Context
	private ServletContext context;
	
	@Context
	private HttpHeaders headers;

	protected XMIPolystoreConnection getEngine() {
		return (XMIPolystoreConnection) context.getAttribute(QLRestServer.QUERY_ENGINE);
	}

	protected QLRestServer.RestArguments getRestArguments() throws IOException {
		String s = headers.getRequestHeader("QL-RestArguments").get(0);
		return QLRestServer.RestArguments.parse(new StringReader(s));			
	}
}
