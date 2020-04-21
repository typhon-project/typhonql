package engineering.swat.typhonql.server.crud;

import java.util.Map;

import javax.ws.rs.PATCH;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.core.Response;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import nl.cwi.swat.typhonql.client.CommandResult;

@Path("/{entityName}/{uuid}")
public class EntityResource extends TyphonDALResource {

	private static final Logger logger = LogManager.getLogger(EntitiesResource.class);

	@POST
	public Response deleteEntity(@PathParam("entityName") String entityName, @PathParam("uuid") String uuid) {
		String query = "delete " + entityName + " e where e.@id == #" +uuid;
		CommandResult cr = getEngine().executeUpdate(getModel(), getDatabaseInfo(), query);
		return Response.ok().build();
	}
	
	@PATCH
	public Response updateEntity(@PathParam("entityName") String entityName, @PathParam("uuid") String uuid, Map<String, String> fields) {
		String query = "update " + entityName + " e where e.@id == #" + uuid + " set { "
				+ serializeFields(fields) + "}";
		CommandResult cr = getEngine().executeUpdate(getModel(), getDatabaseInfo(), query);
		return Response.ok().build();
	}

}