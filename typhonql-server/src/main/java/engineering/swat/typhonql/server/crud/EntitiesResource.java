package engineering.swat.typhonql.server.crud;

import java.io.IOException;
import java.util.List;
import java.util.stream.Collectors;

import javax.servlet.ServletContext;
import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.core.Context;
import javax.ws.rs.core.MediaType;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import engineering.swat.typhonql.server.QLRestServer;
import engineering.swat.typhonql.server.QueryEngine;
import nl.cwi.swat.typhonql.client.CommandResult;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;
import nl.cwi.swat.typhonql.workingset.Entity;

@Path("/{entityName}")
public class EntitiesResource {

	private static final Logger logger = LogManager.getLogger(EntitiesResource.class);
	
	@Context
	ServletContext context;

	@GET
	@Produces(MediaType.APPLICATION_JSON)
	public List<Entity> getEntites(@PathParam("entityName") String entityName) {
		try {
			logger.trace("Getting all entities of type: " + entityName);
			ResultTable result = getEngine().executeQuery("from " + entityName + " e select e");
			return result.getValues().stream().map(vs -> new Entity(entityName, (String) vs.get(0)))
					.collect(Collectors.toList());
		} catch (IOException e) {
			throw new RuntimeException(e);
		}

	}

	private QueryEngine getEngine() {
		return (QueryEngine) context.getAttribute(QLRestServer.QUERY_ENGINE);
	}

	@POST
	@Produces(MediaType.APPLICATION_JSON)
	public CommandResult createEntity(Entity entity) {
		return new CommandResult(0);
	}

}