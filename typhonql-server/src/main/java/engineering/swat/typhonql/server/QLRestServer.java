package engineering.swat.typhonql.server;

import java.io.IOException;
import java.io.Reader;
import java.io.Writer;
import java.util.Arrays;
import java.util.List;
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
import nl.cwi.swat.typhonql.workingset.JsonSerializableResult;
import nl.cwi.swat.typhonql.workingset.WorkingSet;

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
        context.addServlet(jsonGetHandler(r -> handleQuery(engine, r)), "/query");
        context.addServlet(jsonPostHandler(r -> handleCommand(engine, r)), "/update");
        context.addServlet(jsonPostHandler(r -> handlePreparedCommand(engine, r)), "/preparedUpdate");
        context.addServlet(jsonPostHandler(r -> handleInitialize(engine, r)), "/initialize");
        context.addServlet(jsonPostHandler(r -> handleReset(engine, r)), "/reset");
        context.addServlet(jsonPostHandler(r -> handleChangeModel(engine, r)), "/changeModel");
        server.setHandler(context);
        server.start();
        System.err.println("Server is running, press Ctrl-C to terminate");
        server.join();
	}
	
	


	private static JsonSerializableResult handleReset(QueryEngine engine, HttpServletRequest r) throws IOException {
		return engine.resetDatabase();
	}

	private static WorkingSet handleQuery(QueryEngine engine, HttpServletRequest r) throws IOException {
		String query = r.getParameter("q");
		if (query == null || query.isEmpty()) {
			throw new IOException("Missing q parameter");
		}
		logger.trace("Running query: {}", query);
		return engine.executeQuery(query);
	}


	private static class CommandArgs {
		public String command;
		public String[] parameterNames;
		public String[][] boundRows;
		
		static CommandArgs fromJSON(Reader source)  throws JsonParseException, JsonMappingException, IOException  {
			return mapper.readValue(source, new TypeReference<CommandArgs> () {});
		}
		
		@Override
		public String toString() {
			if (parameterNames != null && boundRows != null) {
				return command + " args: " + Arrays.toString(parameterNames) + " rows: " + boundRows.length;
			}
			return command;
		}
	}

	private static CommandResult handleCommand(QueryEngine engine, HttpServletRequest r) throws IOException {
		CommandArgs args;
		try {
			args = CommandArgs.fromJSON(r.getReader());
		} catch (IOException e) {
			throw new IOException("Failure to parse args", e);
		}
		logger.trace("Running command: {}", args);
        return engine.executeCommand(args.command);
	}

	private static JsonSerializableResult handlePreparedCommand(QueryEngine engine, HttpServletRequest r) throws IOException {
		CommandArgs args;
		try {
			args = CommandArgs.fromJSON(r.getReader());
		} catch (IOException e) {
			throw new IOException("Failure to parse args", e);
		}
		if (args.parameterNames == null || args.parameterNames.length == 0 || args.boundRows == null || args.boundRows.length == 0) {
			throw new IOException("Missing arguments to the command");
		}
		CommandResult[] result = engine.executeCommand(args.command, args.parameterNames, args.boundRows);
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
	
	private static class InitializeArgs {
		public String xmi;
		public List<DatabaseInfo> databaseInfo;
		
		static InitializeArgs fromJSON(Reader source) throws JsonParseException, JsonMappingException, IOException {
			return mapper.readValue(source, new TypeReference<InitializeArgs>() {});
		}
		@Override
		public String toString() {
			return   "xmi: " + xmi
					+"\ndbInfo: " + databaseInfo;
		}
	}

	private static JsonSerializableResult handleInitialize(QueryEngine engine, HttpServletRequest r) throws IOException {
		InitializeArgs args;
		try {
			args = InitializeArgs.fromJSON(r.getReader());
		} catch (IOException e) {
			throw new IOException("Failure to parse args", e);
		}
		logger.trace("Initializing db with: {}", args);
		return engine.initialize(args.xmi, args.databaseInfo);
	}

	private static class ChangeXMIArgs {
		public String newXMI;
		
		static ChangeXMIArgs fromJSON(Reader source) throws JsonParseException, JsonMappingException, IOException {
			return mapper.readValue(source, new TypeReference<ChangeXMIArgs>() {});
		}
	}

	private static JsonSerializableResult handleChangeModel(QueryEngine engine, HttpServletRequest r) throws IOException {
		ChangeXMIArgs args;
		try {
			args = ChangeXMIArgs.fromJSON(r.getReader());
		} catch (IOException e) {
			throw new IOException("Failure to parse args", e);
		}
		logger.trace("Received new xmi model: {}", args.newXMI);
		return engine.changeModel(args.newXMI);
	}


	@FunctionalInterface 
	private interface ServletHandler {
		JsonSerializableResult handle(HttpServletRequest req) throws ServletException, IOException;
	}
	
	private static void handle(HttpServletRequest req, HttpServletResponse resp, ServletHandler handler) throws ServletException, IOException {
		try (ServletOutputStream responseStream = resp.getOutputStream()) {
			try { // nested try so that we can report an error before the stream is closed
				JsonSerializableResult result = handler.handle(req);
				resp.setStatus(HttpServletResponse.SC_OK);
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
	
	private static ServletHolder jsonGetHandler(ServletHandler handler) {
		return new ServletHolder(new HttpServlet() {
			private static final long serialVersionUID = -1652905724147115804L;
			@Override
			protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
				handle(req, resp, handler);
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
