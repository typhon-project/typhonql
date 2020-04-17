package engineering.swat.typhonql.server;

import java.io.IOException;
import java.io.Reader;
import java.io.Writer;
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
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.server.ServerConnector;
import org.eclipse.jetty.servlet.ServletContextHandler;
import org.eclipse.jetty.servlet.ServletHolder;

import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.core.JsonParseException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JavaType;
import com.fasterxml.jackson.databind.JsonMappingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.module.paramnames.ParameterNamesModule;

import nl.cwi.swat.typhonql.client.CommandResult;
import nl.cwi.swat.typhonql.client.DatabaseInfo;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;
import nl.cwi.swat.typhonql.workingset.JsonSerializableResult;

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
        QueryEngine engine = new QueryEngine();
        Server server = new Server();
        ServerConnector http = new ServerConnector(server);
        http.setHost("0.0.0.0");
        http.setPort(Integer.parseInt(args[0]));
        http.setIdleTimeout(30000);
        server.addConnector(http);

        ServletContextHandler context = new ServletContextHandler();
        context.setContextPath("/");
        context.setMaxFormContentSize(100*1024*1024); // 100MB should be max for parameters
        context.addServlet(jsonGetPostHandler(r -> handleNewQuery(engine, fakeGetArguments(r), r), r -> handleNewQuery(engine, parseArguments(r), r)), "/query");
        context.addServlet(jsonPostHandler(r -> handleCommand(engine, parseArguments(r), r)), "/update");
        context.addServlet(jsonPostHandler(r -> handleDDLCommand(engine, parseArguments(r), r)), "/ddl");
        context.addServlet(jsonPostHandler(r -> handlePreparedCommand(engine, parseArguments(r), r)), "/preparedUpdate");
        context.addServlet(jsonPostHandler(r -> handleInitialize(engine, parseArguments(r), r)), "/initialize");
        context.addServlet(jsonPostHandler(r -> handleReset(engine, parseArguments(r), r)), "/reset");
        context.addServlet(jsonPostHandler(r -> handleChangeModel(engine, parseArguments(r), r)), "/changeModel");
        server.setHandler(context);
        server.start();
        System.err.println("Server is running, press Ctrl-C to terminate");
        server.join();
	}
	
	private static RestArguments fakeGetArguments(HttpServletRequest r) throws IOException {
		RestArguments result = new RestArguments();
		result.query = r.getParameter("q");
		if (result.query == null || result.query.isEmpty()) {
			throw new IOException("Missing q parameter");
		}
		return result;
	}

	private static RestArguments parseArguments(HttpServletRequest r) throws IOException {
		try {
			return RestArguments.fromJSON(r.getReader());
		} catch (IOException e) {
			throw new IOException("Failure to parse args", e);
		}
	}

	private static class RestArguments {
		// should always be there
		public String xmi;
		public List<DatabaseInfo> databaseInfo;

		// depends on the command which one is filled in or not
		public String query;
		public String command;
		public String[] parameterNames;
		public String[][] boundRows;
		
		static RestArguments fromJSON(Reader source)  throws JsonParseException, JsonMappingException, IOException  {
			return mapper.readValue(source, new TypeReference<RestArguments> () {});
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


	private static JsonSerializableResult handleDDLCommand(QueryEngine engine, RestArguments args, HttpServletRequest r) throws IOException {
		if (isEmpty(args.command)) {
			throw new IOException("Missing command field in post body");
		}
		logger.trace("Running DDL command: {}", args);
        return engine.executeDDL(args.xmi, args.databaseInfo, args.command);
	}


	private static JsonSerializableResult handleReset(QueryEngine engine, RestArguments args, HttpServletRequest r) throws IOException {
		return engine.resetDatabase(args.xmi, args.databaseInfo);
	}

	private static ResultTable handleNewQuery(QueryEngine engine, RestArguments args, HttpServletRequest r) throws IOException {
		if (isEmpty(args.query)) {
			throw new IOException("Missing query parameter in post body");
		}
		logger.trace("Running query: {}", args.query);
		return engine.executeQuery(args.xmi, args.databaseInfo, args.query);
	}



	private static CommandResult handleCommand(QueryEngine engine, RestArguments args, HttpServletRequest r) throws IOException {
		if (isEmpty(args.command)) {
			throw new IOException("Missing command in post body");
		}
		logger.trace("Running command: {}", args);
        return engine.executeCommand(args.xmi, args.databaseInfo, args.command);
	}

	private static JsonSerializableResult handlePreparedCommand(QueryEngine engine, RestArguments args, HttpServletRequest r) throws IOException {
		if (args.parameterNames == null || args.parameterNames.length == 0 || args.boundRows == null || args.boundRows.length == 0) {
			throw new IOException("Missing arguments to the command");
		}
		CommandResult[] result = engine.executeCommand(args.xmi, args.databaseInfo, args.command, args.parameterNames, args.boundRows);
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
	
	private static JsonSerializableResult handleInitialize(QueryEngine engine, RestArguments args, HttpServletRequest r) throws IOException {
		if (isEmpty(args.xmi) || args.databaseInfo == null || args.databaseInfo.isEmpty()) {
			throw new IOException("Missing xmi & database info in post body");
		}
		logger.trace("Initializing db with: {}", args);
		return engine.initialize(args.xmi, args.databaseInfo);
	}

	private static JsonSerializableResult handleChangeModel(QueryEngine engine, RestArguments args, HttpServletRequest r) throws IOException {
		throw new IOException("Operation not supported anymore");
	}


	@FunctionalInterface 
	private interface ServletHandler {
		JsonSerializableResult handle(HttpServletRequest req) throws ServletException, IOException;
	}
	
	private static void handle(HttpServletRequest req, HttpServletResponse resp, ServletHandler handler) throws ServletException, IOException {
		try (ServletOutputStream responseStream = resp.getOutputStream()) {
			try { // nested try so that we can report an error before the stream is closed
				long start = System.nanoTime();
				JsonSerializableResult result = handler.handle(req);
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
					}
				}
				else {
					// we cannot reset the stream, so we just write some broken json
					responseStream.println("\' \" <<< } {{{{ Error: " + e.getMessage());
				}
			}
		}
	}
	
	private static ServletHolder jsonGetPostHandler(ServletHandler handler, ServletHandler newHandler) {
		return new ServletHolder(new HttpServlet() {
			private static final long serialVersionUID = -1652905724147115804L;
			@Override
			protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
				handle(req, resp, handler);
			}
			
			@Override
			protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
				handle(req, resp, newHandler);
			}
		});
	}

	
	private static ServletHolder jsonPostHandler(ServletHandler handler) {
		return new ServletHolder(new HttpServlet() {
			private static final long serialVersionUID = 4128294886643135039L;

			@Override
			protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
				handle(req, resp, handler);
			}
		});
	}
	


}
