package engineering.swat.typhonql.server.crud;

import java.io.IOException;
import java.io.OutputStream;

import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.PathParam;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;

import nl.cwi.swat.typhonql.client.CommandResult;
import nl.cwi.swat.typhonql.workingset.Entity;
import nl.cwi.swat.typhonql.workingset.JsonSerializableResult;

@Path("/{entityName}")
public class EntitiesResource implements JsonSerializableResult {

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public Entity getEntites(@PathParam("entityName") String entityName) {
        return new Entity(entityName, "pablo");
    }

    @POST
    @Produces(MediaType.APPLICATION_JSON)
    public CommandResult createEntity(Entity entity) {
    	return new CommandResult(0);
    }

	@Override
	public void serializeJSON(OutputStream target) throws IOException {
		// TODO Auto-generated method stub
		
	}
}