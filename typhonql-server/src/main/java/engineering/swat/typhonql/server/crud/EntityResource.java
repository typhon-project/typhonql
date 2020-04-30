package engineering.swat.typhonql.server.crud;

import java.io.IOException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import javax.ws.rs.DELETE;
import javax.ws.rs.GET;
import javax.ws.rs.NotFoundException;
import javax.ws.rs.PATCH;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import engineering.swat.typhonql.server.QLRestServer;
import nl.cwi.swat.typhonql.client.CommandResult;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

@Path("/{entityName}/{uuid}")
public class EntityResource extends TyphonDALResource {

	private static final Logger logger = LogManager.getLogger(EntitiesResource.class);
	
	@GET
	@Produces(MediaType.APPLICATION_JSON)
	public Map<String, String> getEntity(@PathParam("entityName") String entityName, @PathParam("uuid") String uuid) throws IOException {
		logger.trace("Getting entity " + uuid + " of type: " + entityName);
		QLRestServer.RestArguments args = getRestArguments();
		ResultTable result = getEngine().executeGetEntity(args.xmi, args.databaseInfo, entityName, uuid);
		if (result.isEmpty()) {
			throw new NotFoundException();
		}
		List<String> fields = result.getValues().iterator().next();
		Map<String, String> r = new HashMap<String, String>();
		r.put("@id", "#" + uuid);
		for (int i = 0; i < result.getColumnNames().size(); i++) {
			r.put(result.getColumnNames().get(i), fields.get(i));
		}
		return r;
	}

	@DELETE
	public Response deleteEntity(@PathParam("entityName") String entityName, @PathParam("uuid") String uuid) throws IOException {
		String query = "delete " + entityName + " e where e.@id == #" +uuid;
		QLRestServer.RestArguments args = getRestArguments();
		CommandResult cr = getEngine().executeUpdate(args.xmi, args.databaseInfo, query);
		return Response.ok().build();
	}
	
	@PATCH
	public Response updateEntity(@PathParam("entityName") String entityName, @PathParam("uuid") String uuid, Map<String, String> fields) throws IOException {
		String query = "update " + entityName + " e where e.@id == #" + uuid + " set { "
				+ concatenateFields(fields) + "}";
		QLRestServer.RestArguments args = getRestArguments();
		CommandResult cr = getEngine().executeUpdate(args.xmi, args.databaseInfo, query);
		return Response.ok().build();
	}

}