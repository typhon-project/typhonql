package engineering.swat.typhonql.server.crud;

import java.io.IOException;
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

import com.fasterxml.jackson.databind.annotation.JsonDeserialize;

import engineering.swat.typhonql.server.QLRestServer;
import nl.cwi.swat.typhonql.client.CommandResult;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

@Path("/{entityName}")
public class EntitiesResource extends TyphonDALResource {
	
	private static final Logger logger = LogManager.getLogger(EntitiesResource.class);

	@GET
	@Produces(MediaType.APPLICATION_JSON)
	public List<Map<String, String>> getEntites(@PathParam("entityName") String entityName) throws IOException {
		logger.trace("Getting all entities of type: " + entityName);
		QLRestServer.RestArguments args = getRestArguments();
		ResultTable result = getEngine().executeQuery(args.xmi, args.databaseInfo,
				"from " + entityName + " e select e");
		return result.getValues().stream().map(vs -> { 
					Map<String, String> map = new HashMap<>();
					map.put("@id", vs.get(0)); 
					return map; })
				.collect(Collectors.toList());
	}

	@POST
	@Produces(MediaType.APPLICATION_JSON)
	public Response createEntity(@PathParam("entityName") String entityName, 
			@JsonDeserialize(using = CreationEntityDeserializer.class) CreationEntity entity) throws IOException {
		String query = "insert " + entityName + " { " + concatenateFields(entity.getFields()) + "}";
 		try {
 			QLRestServer.RestArguments args = getRestArguments();
			CommandResult cr = getEngine().executeUpdate(args.xmi, args.databaseInfo, query);
			return Response.created(URI.create("/" + entityName + "/" + cr.getCreatedUuids().values().iterator().next())).build();
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