/********************************************************************************
* Copyright (c) 2018-2020 CWI & Swat.engineering 
*
* This program and the accompanying materials are made available under the
* terms of the Eclipse Public License 2.0 which is available at
* http://www.eclipse.org/legal/epl-2.0.
*
* This Source Code may also be made available under the following Secondary
* Licenses when the conditions for such availability set forth in the Eclipse
* Public License, v. 2.0 are satisfied: GNU General Public License, version 2
* with the GNU Classpath Exception which is
* available at https://www.gnu.org/software/classpath/license.html.
*
* SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0
********************************************************************************/

package engineering.swat.typhonql.server;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.Reader;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Base64;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import javax.servlet.ServletException;
import javax.servlet.ServletOutputStream;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.eclipse.jetty.server.Handler;
import org.eclipse.jetty.server.HttpConfiguration;
import org.eclipse.jetty.server.HttpConnectionFactory;
import org.eclipse.jetty.server.Server;
import org.eclipse.jetty.server.ServerConnector;
import org.eclipse.jetty.server.handler.gzip.GzipHandler;
import org.eclipse.jetty.servlet.ServletContextHandler;
import org.eclipse.jetty.servlet.ServletHolder;
import org.glassfish.jersey.jackson.internal.jackson.jaxrs.json.JacksonJaxbJsonProvider;
import org.glassfish.jersey.server.ResourceConfig;
import org.glassfish.jersey.servlet.ServletContainer;

import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.JsonToken;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.DeserializationContext;
import com.fasterxml.jackson.databind.JavaType;
import com.fasterxml.jackson.databind.JsonDeserializer;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.annotation.JsonDeserialize;
import com.fasterxml.jackson.databind.module.SimpleModule;
import com.fasterxml.jackson.module.paramnames.ParameterNamesModule;

import engineering.swat.typhonql.server.crud.EntityDeltaFields;
import engineering.swat.typhonql.server.crud.EntityDeltaFieldsDeserializer;
import engineering.swat.typhonql.server.crud.EntityFields;
import engineering.swat.typhonql.server.crud.EntityFieldsDeserializer;
import io.usethesource.vallang.type.Type;
import nl.cwi.swat.typhonql.client.DatabaseInfo;
import nl.cwi.swat.typhonql.client.JsonSerializableResult;
import nl.cwi.swat.typhonql.client.XMIPolystoreConnection;
import nl.cwi.swat.typhonql.client.resulttable.QLSerialization;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

public class QLRestServer {

	public static String QUERY_ENGINE = "queryEngine";

	private static final Logger logger = LogManager.getLogger(QLRestServer.class);
	private static final ObjectMapper mapper;

	static {
		mapper = new ObjectMapper().configure(JsonGenerator.Feature.AUTO_CLOSE_TARGET, true)
				.registerModule(new ParameterNamesModule());
		mapper.canDeserialize(mapper.getTypeFactory().constructSimpleType(DatabaseInfo.class, new JavaType[0]));
	}

	public static void main(String[] args) throws Exception {
		if (DatabaseInfo.class.getConstructors()[0].getParameters()[0].getName().equals("arg0")) {
			throw new RuntimeException(
					"TyphonQL class was not compiled with parameters flag, server cannot work without it");
		}

		if (args.length != 1) {
			System.err.println("Missing port to run the reset server on, pass it as the first argument");
			return;
		}
		XMIPolystoreConnection engine = new XMIPolystoreConnection();

		Server server = new Server();

		HttpConfiguration config = new HttpConfiguration();
		config.setRequestHeaderSize(10*1024*1024);
		ServerConnector http = new ServerConnector(server, new HttpConnectionFactory(config));
		http.setHost("0.0.0.0");
		http.setPort(Integer.parseInt(args[0]));
		http.setIdleTimeout(30000);
		server.addConnector(http);

		ServletContextHandler context = new ServletContextHandler();

		context.setContextPath("/");

		context.setMaxFormContentSize(100 * 1024 * 1024); // 100MB should be max for parameters
		context.addServlet(jsonPostHandler(engine, QLRestServer::handleNewQuery), "/query");
		context.addServlet(jsonPostHandler(engine, QLRestServer::handleCommand), "/update");
		context.addServlet(jsonPostHandler(engine, QLRestServer::handleDDLCommand), "/ddl");
		context.addServlet(jsonPostHandler(engine, QLRestServer::handleReset), "/reset");

		// REST DAL

		context.setAttribute(QUERY_ENGINE, engine);
		
		ObjectMapper crudMapper = QLSerialization.mapper;

		SimpleModule module = new SimpleModule();
		// adding our custom serializer and deserializer
		module.addDeserializer(EntityFields.class, new EntityFieldsDeserializer());
		module.addDeserializer(EntityDeltaFields.class, new EntityDeltaFieldsDeserializer());
		// registering the module with ObjectMapper
		crudMapper.registerModule(module);
		// create JsonProvider to provide custom ObjectMapper
		JacksonJaxbJsonProvider provider = new JacksonJaxbJsonProvider();
		provider.setMapper(crudMapper);

		// configure REST service
		ResourceConfig rc = new ResourceConfig();
		rc.register(provider);
		rc.packages("engineering.swat.typhonql.server.crud");
		
		ServletHolder servletHolder = new ServletHolder(new ServletContainer(rc));

		context.addServlet(servletHolder, "/crud/*");

		servletHolder.setInitOrder(0);
		//servletHolder.setInitParameter("jersey.config.server.provider.packages",
		//		"engineering.swat.typhonql.server.crud");

		server.setHandler(wrapCompression(context));

		server.start();
		System.err.println("Server is running, press Ctrl-C to terminate");
		server.join();
	}

	private static final byte[] RESULT_OK_MESSAGE = "{\"result\":\"ok\"}".getBytes(StandardCharsets.UTF_8);
	private static JsonSerializableResult RESULT_OK = new JsonSerializableResult() {
		public void addWarnings(String warnings) {};
		
		@Override
		public Type getType() {
			return null;
		}
		
		@Override
		public void serializeJSON(OutputStream target) throws IOException {
			target.write(RESULT_OK_MESSAGE);
		}
	};

	public static class RestArguments {
		// should always be there
		public String xmi;
		public List<DatabaseInfo> databaseInfo;
		public boolean validate = false;

		// depends on the command which one is filled in or not
		public String query;
		public String[] parameterNames;
		public String[] parameterTypes;
		public String[][] boundRows;
	    @JsonDeserialize(using = Base64Deserializer.class)
		public Map<String, InputStream> blobs;
	    
	    private RestArguments() {}

		public static RestArguments parse(HttpServletRequest r) throws IOException {
			return parse(r.getReader(), r.getHeader("QL-XMI"), r.getHeader("QL-DatabaseInfo"));
		}

		public static RestArguments parse(Reader r, String xmi, String databaseInfo) throws IOException {
			try {
				RestArguments result;
				if (r != null) {
                    result = mapper.readValue(r, new TypeReference<RestArguments>() {
                    });
				}
				else {
					result = new RestArguments();
				}
				logger.trace("Parsed args: {}", result);
				result.xmi = xmi;
				result.databaseInfo = mapper.readValue(databaseInfo, new TypeReference<List<DatabaseInfo>>() {});
				logger.trace("Received arguments: {}", result);
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
			return "{\n" + ((query != null && !query.isEmpty()) ? ("query: " + query + "\n") : "")
					+ ((parameterNames != null && parameterNames.length > 0)
							? ("parameterNames: " + Arrays.toString(parameterNames) + "\n")
							: "")
					+ ((parameterTypes != null && parameterTypes.length > 0)
							? ("parameterTypes: " + Arrays.toString(parameterTypes) + "\n")
							: "")
					+ ((boundRows != null) ? ("boundRows: " + boundRows.length + "\n") : "") 
					+ ((blobs != null) ? "blobs: " + blobs.keySet() + "\n" : "")
					+ "validate: " + validate + "\n"
					+ "xmi: " + xmi + "\n"
					+ "databaseInfo" + databaseInfo + "}";
		}
	}
	
	private static class Base64Deserializer extends JsonDeserializer<Map<String, InputStream>> {

		@Override
		public Map<String, InputStream> deserialize(JsonParser p, DeserializationContext ctxt) throws IOException, JsonProcessingException {
			Map<String, InputStream> result = new HashMap<>();
			JsonToken current = p.nextToken();
			while (!current.isStructEnd()) {
				assert current == JsonToken.FIELD_NAME;
				String fieldName = p.currentName();
				current = p.nextValue();
				assert current == JsonToken.VALUE_STRING;
				byte[] encodedBytes = p.getValueAsString().getBytes(StandardCharsets.ISO_8859_1);
				result.put(fieldName, Base64.getDecoder().wrap(new ByteArrayInputStream(encodedBytes)));
				current = p.nextToken();
			}
			return result;
		}
		
	}

	private static boolean isEmpty(String value) {
		return value == null || value.isEmpty();
	}

	private static JsonSerializableResult handleDDLCommand(XMIPolystoreConnection engine, RestArguments args,
			HttpServletRequest r) throws IOException {
		if (isEmpty(args.query)) {
			throw new IOException("Missing query field in post body");
		}
		logger.trace("Running DDL command: {}", args);
		engine.executeDDLUpdate(args.xmi, args.databaseInfo, args.query);
		return RESULT_OK;
	}

	private static JsonSerializableResult handleReset(XMIPolystoreConnection engine, RestArguments args,
			HttpServletRequest r) throws IOException {
		engine.resetDatabases(args.xmi, args.databaseInfo);
		return RESULT_OK;
	}

	private static JsonSerializableResult handleNewQuery(XMIPolystoreConnection engine, RestArguments args, HttpServletRequest r)
			throws IOException {
		if (isEmpty(args.query)) {
			throw new IOException("Missing query parameter in post body");
		}
		logger.trace("Running query: {}", args.query);
		return engine.executeQuery(args.xmi, args.databaseInfo, args.query, args.validate);
	}


	private static JsonSerializableResult handleCommand(XMIPolystoreConnection engine, RestArguments args, HttpServletRequest r)
			throws IOException {
		if (isEmpty(args.query)) {
			throw new IOException("Missing command in post body");
		}
        logger.trace("Running command: {}", args);
		if (args.parameterNames != null && args.parameterNames.length > 0) {
			if (args.parameterTypes == null || args.parameterTypes.length == 0) {
				throw new IOException("Missing parameterTypes to the command");
			}
            if (args.parameterNames.length != args.parameterTypes.length) {
                throw new IOException("Mismatch between length of parameter names and parameter types");
            }
            return stringArray(engine.executePreparedUpdate(args.xmi, args.databaseInfo, args.blobs, args.query,
                    args.parameterNames, args.parameterTypes, args.boundRows, args.validate));
			
		}
		else {
            return stringArray(engine.executeUpdate(args.xmi, args.databaseInfo, args.blobs, args.query, args.validate));
		}
	}
	
	private static JsonSerializableResult stringArray(String[] result) {
		return new JsonSerializableResult() {
			@Override
			public void addWarnings(String warnings) {
			}
			
			@Override
			public Type getType() {
				return null;
			}

			@Override
			public void serializeJSON(OutputStream target) throws IOException {
				mapper.writeValue(target, result);
			}
		};
	}

	@FunctionalInterface
	private interface ServletHandler {
		JsonSerializableResult handle(XMIPolystoreConnection engine, RestArguments args, HttpServletRequest r)
				throws ServletException, IOException;
	}

	private static void handle(XMIPolystoreConnection engine, HttpServletRequest req, HttpServletResponse resp,
			ServletHandler handler) throws ServletException, IOException {
		try (ServletOutputStream responseStream = resp.getOutputStream()) {
			try { // nested try so that we can report an error before the stream is closed
				long start = System.nanoTime();
				JsonSerializableResult result = handler.handle(engine, RestArguments.parse(req), req);
				long stop = System.nanoTime();
				resp.setStatus(HttpServletResponse.SC_OK);
				resp.setHeader("QL-Wall-Time-Ms", Long.toString(TimeUnit.NANOSECONDS.toMillis(stop - start)));
				resp.setContentType("application/json");
				result.serializeJSON(responseStream);
			} catch (Exception e) {
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
				} else {
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
			protected void doPost(HttpServletRequest req, HttpServletResponse resp)
					throws ServletException, IOException {
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
