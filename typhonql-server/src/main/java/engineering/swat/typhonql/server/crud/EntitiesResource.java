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
import java.net.URI;
import java.util.Map;
import java.util.stream.Collectors;

import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.QueryParam;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import engineering.swat.typhonql.server.QLRestServer;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

@Path("/{entityName}")
public class EntitiesResource extends TyphonDALResource {
	
	private static final Logger logger = LogManager.getLogger(EntitiesResource.class);

	@GET
	@Produces(MediaType.APPLICATION_JSON)
	public ResultTable getEntites(@PathParam("entityName") String entityName, @QueryParam("where") String whereClause, @QueryParam("limit") String limit, @QueryParam("sortBy") String sortBy) throws IOException {
		logger.trace("Getting all entities of type: {}", entityName);
		QLRestServer.RestArguments args = getRestArguments();
		ResultTable result = getEngine().executeListEntities(args.xmi, args.databaseInfo, entityName, whereClause ,limit, sortBy);
		return result;
	}

	@POST
	@Produces(MediaType.APPLICATION_JSON)
	public Response createEntity(@PathParam("entityName") String entityName, 
			EntityFields entity) throws IOException {
		String query = "insert " + entityName + " { " + concatenateFields(entity.getFields()) + "}";
 		try {
 			QLRestServer.RestArguments args = getRestArguments();
			String[] uuids = getEngine().executeUpdate(args.xmi, args.databaseInfo, args.blobs, query, true);
			return Response.created(URI.create("/" + entityName + "/" + uuids[0])).build();
		} catch (RuntimeException e) {
			return Response.serverError().build();
		}
	}
	
	protected String concatenateFields(Map<String, Object> fields) throws IOException {
		return String.join(", ",
				fields.entrySet().stream().map(e -> e.getKey() + " : "
						+ value2String(e.getValue())).collect(Collectors.toList()).toArray(new String[0]));
	}

	private String value2String(Object value) {
		if (value instanceof String) {
			return (String) value;
		}
		else if (value instanceof String[]) {
			return "[" + String.join(", ", (String[]) value) + "]";
		}
		else {
			throw new RuntimeException("Failure to parse json body representing entity");
		}
	}

}
