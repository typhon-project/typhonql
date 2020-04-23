package engineering.swat.typhonql.server.crud;

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

import nl.cwi.swat.typhonql.client.CommandResult;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

@Path("/{entityName}/{uuid}")
public class EntityResource extends TyphonDALResource {

	private static final Logger logger = LogManager.getLogger(EntitiesResource.class);
	
	@GET
	@Produces(MediaType.APPLICATION_JSON)
	public Map<String, String> getEntity(@PathParam("entityName") String entityName, @PathParam("uuid") String uuid) {
		logger.trace("Getting entity " + uuid + " of type: " + entityName);
		ResultTable result = getEngine().executeGetEntity(getModel(), getDatabaseInfo(), entityName, uuid);
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
	public Response deleteEntity(@PathParam("entityName") String entityName, @PathParam("uuid") String uuid) {
		String query = "delete " + entityName + " e where e.@id == #" +uuid;
		CommandResult cr = getEngine().executeUpdate(getModel(), getDatabaseInfo(), query);
		return Response.ok().build();
	}
	
	@PATCH
	public Response updateEntity(@PathParam("entityName") String entityName, @PathParam("uuid") String uuid, Map<String, String> fields) {
		String query = "update " + entityName + " e where e.@id == #" + uuid + " set { "
				+ concatenateFields(fields) + "}";
		CommandResult cr = getEngine().executeUpdate(getModel(), getDatabaseInfo(), query);
		return Response.ok().build();
	}

}