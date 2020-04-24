package engineering.swat.typhonql.server;

import java.io.IOException;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.TimeUnit;
import javax.servlet.ServletException;
import javax.servlet.ServletOutputStream;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.eclipse.jetty.server.Handler;
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.server.ServerConnector;
import org.eclipse.jetty.server.handler.gzip.GzipHandler;
import org.eclipse.jetty.servlet.ServletContextHandler;
import org.eclipse.jetty.servlet.ServletHolder;
import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JavaType;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.module.paramnames.ParameterNamesModule;
import nl.cwi.swat.typhonql.client.CommandResult;
import nl.cwi.swat.typhonql.client.DatabaseInfo;
import nl.cwi.swat.typhonql.client.XMIPolystoreConnection;
import nl.cwi.swat.typhonql.client.resulttable.JsonSerializableResult;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

public class QLRestServer {
	private static final Logger logger = LogManager.getLogger(QLRestServer.class);
	private static final ObjectMapper mapper;
	
	static {
		mapper = new ObjectMapper()
				.configure(JsonGenerator.Feature.AUTO_CLOSE_TARGET, true)
				.registerModule(new ParameterNamesModule())
				;
		mapper.canDeserialize(mapper.getTypeFactory().constructSimpleType(DatabaseInfo.class, new JavaType[0]));
	}

	public static void main(String[] args) throws Exception {
		if (DatabaseInfo.class.getConstructors()[0].getParameters()[0].getName().equals("arg0")) {
			throw new RuntimeException("TyphonQL class was not compiled with parameters flag, server cannot work without it");
		}
		
		if (args.length != 1) {
			System.err.println("Missing port to run the reset server on, pass it as the first argument");
			return;
		}
        XMIPolystoreConnection engine = new XMIPolystoreConnection();

        Server server = new Server();
        ServerConnector http = new ServerConnector(server);
        http.setHost("0.0.0.0");
        http.setPort(Integer.parseInt(args[0]));
        http.setIdleTimeout(30000);
        server.addConnector(http);

        ServletContextHandler context = new ServletContextHandler();
        context.setContextPath("/");
        context.setMaxFormContentSize(100*1024*1024); // 100MB should be max for parameters
        context.addServlet(jsonPostHandler(engine, QLRestServer::handleNewQuery), "/query");
        context.addServlet(jsonPostHandler(engine, QLRestServer::handleCommand), "/update");
        context.addServlet(jsonPostHandler(engine, QLRestServer::handleDDLCommand), "/ddl");
        context.addServlet(jsonPostHandler(engine, QLRestServer::handlePreparedCommand), "/preparedUpdate");
        context.addServlet(jsonPostHandler(engine, QLRestServer::handleReset), "/reset");
        server.setHandler(wrapCompression(context));
        server.start();
        System.err.println("Server is running, press Ctrl-C to terminate");
        server.join();
	}




	private static final byte[] RESULT_OK_MESSAGE = "{\"result\":\"ok\"}".getBytes(StandardCharsets.UTF_8);
	private static JsonSerializableResult RESULT_OK = t -> t.write(RESULT_OK_MESSAGE);

	private static class RestArguments {
		// should always be there
		public String xmi;
		public List<DatabaseInfo> databaseInfo;

		// depends on the command which one is filled in or not
		public String query;
		public String command;
		public String[] parameterNames;
		public String[][] boundRows;

        private static RestArguments parse(HttpServletRequest r) throws IOException {
            try {
                RestArguments result = mapper.readValue(r.getReader(), new TypeReference<RestArguments> () {});
                if (isEmpty(result.xmi)) {
                    throw new IOException("Missing xmi field");
                }
                if (result.databaseInfo == null || result.databaseInfo.isEmpty()) {
                    throw new IOException("Missing databaseInfo field");
                }
                 return result;
            } catch (IOException e) {
                throw new IOException("Failure to parse json body", e);
            }
        }
		
		
		@Override
		public String toString() {
			return "{\n"
                + ((query != null && !query.isEmpty()) ? ("query: " + query + "\n") : "")
                + ((command != null && !command.isEmpty()) ? ("command: " + command + "\n") : "")
                + ((parameterNames != null && parameterNames.length > 0) ? ("parameterNames: " + Arrays.toString(parameterNames) + "\n") : "")
                + ((boundRows != null) ? ("boundRows: " + boundRows.length + "\n") : "")
                + "}";
		}
	}

	private static boolean isEmpty(String value) {
		return value == null || value.isEmpty();
	}


	private static JsonSerializableResult handleDDLCommand(XMIPolystoreConnection engine, RestArguments args, HttpServletRequest r) throws IOException {
		if (isEmpty(args.command)) {
			throw new IOException("Missing command field in post body");
		}
		logger.trace("Running DDL command: {}", args);
        engine.executeDDLUpdate(args.xmi, args.databaseInfo, args.command);
        return RESULT_OK;
	}


	private static JsonSerializableResult handleReset(XMIPolystoreConnection engine, RestArguments args, HttpServletRequest r) throws IOException {
		engine.resetDatabases(args.xmi, args.databaseInfo);
        return RESULT_OK;
	}

	private static ResultTable handleNewQuery(XMIPolystoreConnection engine, RestArguments args, HttpServletRequest r) throws IOException {
		if (isEmpty(args.query)) {
			throw new IOException("Missing query parameter in post body");
		}
		logger.trace("Running query: {}", args.query);
		return engine.executeQuery(args.xmi, args.databaseInfo, args.query);
	}



	private static CommandResult handleCommand(XMIPolystoreConnection engine, RestArguments args, HttpServletRequest r) throws IOException {
		if (isEmpty(args.command)) {
			throw new IOException("Missing command in post body");
		}
		logger.trace("Running command: {}", args);
        return engine.executeUpdate(args.xmi, args.databaseInfo, args.command);
	}

	private static JsonSerializableResult handlePreparedCommand(XMIPolystoreConnection engine, RestArguments args, HttpServletRequest r) throws IOException {
		if (args.parameterNames == null || args.parameterNames.length == 0 || args.boundRows == null || args.boundRows.length == 0) {
			throw new IOException("Missing arguments to the command");
		}
		CommandResult[] result = engine.executePreparedUpdate(args.xmi, args.databaseInfo, args.command, args.parameterNames, args.boundRows);
		return target -> {
			target.write('[');
			boolean first = true;
			for (CommandResult r1 : result) {
				if (!first) {
					target.write(',');
				}
				r1.serializeJSON(target);
				first = false;
			}
			target.write(']');
		}; 
	}
	
	@FunctionalInterface 
	private interface ServletHandler {
		JsonSerializableResult handle(XMIPolystoreConnection engine, RestArguments args, HttpServletRequest r) throws ServletException, IOException;
	}
	
	private static void handle(XMIPolystoreConnection engine, HttpServletRequest req, HttpServletResponse resp, ServletHandler handler) throws ServletException, IOException {
		try (ServletOutputStream responseStream = resp.getOutputStream()) {
			try { // nested try so that we can report an error before the stream is closed
				long start = System.nanoTime();
				JsonSerializableResult result = handler.handle(engine, RestArguments.parse(req), req);
				long stop = System.nanoTime();
				resp.setStatus(HttpServletResponse.SC_OK);
				resp.setHeader("QL-Wall-Time-Ms", Long.toString(TimeUnit.NANOSECONDS.toMillis(stop-start)));
				resp.setContentType("application/json");
				result.serializeJSON(responseStream);
			}
			catch (Exception e) {
                logger.error("Failed to handle response", e);
				if (!resp.isCommitted()) {
					resp.reset();
					resp.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
					try (Writer w = resp.getWriter()) {
						w.write("Error: " + e.getMessage());
						if (e.getCause() != null) {
							w.write("\nOrigin: " + e.getCause().getMessage());
						}
					}
				}
				else {
					// we cannot reset the stream, so we just write some broken json
					responseStream.println("\' \" <<< } {{{{ Error: " + e.getMessage());
				}
			}
		}
	}
	
	private static ServletHolder jsonPostHandler(XMIPolystoreConnection engine, ServletHandler handler) {
		return new ServletHolder(new HttpServlet() {
			private static final long serialVersionUID = 4128294886643135039L;

			@Override
			protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
				handle(engine, req, resp, handler);
			}
		});
	}

	private static Handler wrapCompression(ServletContextHandler originalHandler) {
		GzipHandler gzipHandler = new GzipHandler();
		gzipHandler.setIncludedMimeTypes("text/plain", "text/html", "application/json");
		gzipHandler.setIncludedMethods("GET", "PUT", "POST");
		gzipHandler.setHandler(originalHandler);
		return gzipHandler;
	}
}
