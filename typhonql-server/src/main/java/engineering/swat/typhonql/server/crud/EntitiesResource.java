package engineering.swat.typhonql.server.crud;

import java.net.URI;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import nl.cwi.swat.typhonql.client.CommandResult;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;
@Path("/{entityName}")
public class EntitiesResource extends TyphonDALResource {

	private static final Logger logger = LogManager.getLogger(EntitiesResource.class);

	@GET
	@Produces(MediaType.APPLICATION_JSON)
	public List<Map<String, String>> getEntites(@PathParam("entityName") String entityName) {
		logger.trace("Getting all entities of type: " + entityName);
		ResultTable result = getEngine().executeQuery(getModel(), getDatabaseInfo(),
				"from " + entityName + " e select e");
		return result.getValues().stream().map(vs -> { 
					Map<String, String> map = new HashMap<>();
					map.put("@id", vs.get(0)); 
					return map; })
				.collect(Collectors.toList());
	}

	@POST
	@Produces(MediaType.APPLICATION_JSON)
	public Response createEntity(@PathParam("entityName") String entityName, Map<String, String> fields) {
		String query = "insert " + entityName + " { " + concatenateFields(fields) + "}";
 		try {
			CommandResult cr = getEngine().executeUpdate(getModel(), getDatabaseInfo(), query);
			return Response.created(URI.create("/" + entityName + "/" + cr.getCreatedUuids().values().iterator().next())).build();
		} catch (RuntimeException e) {
			return Response.serverError().build();
		}
	}

}