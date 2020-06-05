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
