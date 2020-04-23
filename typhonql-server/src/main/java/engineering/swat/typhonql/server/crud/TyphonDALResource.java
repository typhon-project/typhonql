package engineering.swat.typhonql.server.crud;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import javax.servlet.ServletContext;
import javax.ws.rs.core.Context;

import engineering.swat.typhonql.server.QLRestServer;
import nl.cwi.swat.typhonql.client.DatabaseInfo;
import nl.cwi.swat.typhonql.client.XMIPolystoreConnection;

public abstract class TyphonDALResource {

	@Context
	private ServletContext context;

	protected XMIPolystoreConnection getEngine() {
		return (XMIPolystoreConnection) context.getAttribute(QLRestServer.QUERY_ENGINE);
	}

	protected String getModel() {
		return (String) context.getAttribute(QLRestServer.MODEL_FOR_DAL);
	}

	protected List<DatabaseInfo> getDatabaseInfo() {
		return (List<DatabaseInfo>) context.getAttribute(QLRestServer.DATABASE_INFO_FOR_DAL);
	}

	protected String concatenateFields(Map<String, String> fields) {
		return String.join(", ",
				fields.entrySet().stream().map(e -> e.getKey() + " : "
						+ e.getValue()).collect(Collectors.toList()).toArray(new String[0]));
	}
}
