package nl.cwi.swat.typhonql.backend.nlp;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.net.URISyntaxException;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.sql.Connection;
import java.sql.SQLException;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.function.Consumer;
import java.util.stream.Collectors;

import org.apache.commons.text.StringSubstitutor;
import org.apache.http.Header;
import org.apache.http.HttpEntity;
import org.apache.http.HttpStatus;
import org.apache.http.auth.AuthScope;
import org.apache.http.auth.UsernamePasswordCredentials;
import org.apache.http.client.CredentialsProvider;
import org.apache.http.client.methods.CloseableHttpResponse;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.ContentType;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.BasicCredentialsProvider;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClientBuilder;
import org.locationtech.jts.geom.Geometry;
//import org.rascalmpl.eclipse.util.ThreadSafeImpulseConsole;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.Engine;
import nl.cwi.swat.typhonql.backend.Field;
import nl.cwi.swat.typhonql.backend.QueryExecutor;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultIterator;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.Runner;
import nl.cwi.swat.typhonql.backend.UpdateExecutor;
import nl.cwi.swat.typhonql.backend.mariadb.MariaDBEngine;
import nl.cwi.swat.typhonql.backend.rascal.Path;
import nl.cwi.swat.typhonql.backend.rascal.TyphonSessionState;
import nl.cwi.swat.typhonql.backend.test.BackendTestCommon;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;


public class NlpEngine extends Engine {
	private static final Logger logger = LoggerFactory.getLogger(NlpEngine.class);
	
	public static final String NLP_REPOSITORY = "nlae";
	private static final ObjectMapper MAPPER = new ObjectMapper();
	
	private final String host;
	private final int port;
	private final String user;
	private final String password;
	
	private static ExecutorService backgroundTask = createFixedTimeoutExecutorService(10, 1, TimeUnit.MINUTES);

	/**
	 * Creates an executor service with a fixed pool size, that will time 
	 * out after a certain period of inactivity.
	 * 
	 * @param poolSize The core- and maximum pool size
	 * @param keepAliveTime The keep alive time
	 * @param timeUnit The time unit
	 * @return The executor service
	 */
	public static ExecutorService createFixedTimeoutExecutorService(
			int poolSize, long keepAliveTime, TimeUnit timeUnit) {
		ThreadPoolExecutor e = new ThreadPoolExecutor(poolSize, poolSize,
						keepAliveTime, timeUnit, new LinkedBlockingQueue<Runnable>());
		e.allowCoreThreadTimeOut(true);
		return e;
	}
	
	
	private static Map<String,String> serializeExpression(Map<String, Object> values) {
		return values.entrySet().stream()
				.collect(Collectors.toMap(
						Entry::getKey, 
						e -> serializeExpression(e.getValue())
					)
				);
	}

	public NlpEngine(ResultStore store, TyphonSessionState state, List<Consumer<List<Record>>> script, Map<String, UUID> uuids,
			String host, int port, String user, String password) {
		super(store, state, script, uuids);
		this.host = host;
		this.port = port;
		this.user = user;
		this.password = password;
	}
	
	private static String literal(String value, String type) {
		return "{\"literal\": {\"value\": \""+ value +"\", \"type\" : \""+ type +"\"}}";
	}
	
	private static String serializeExpression(Object obj) {
		if (obj == null) {
			return literal("null", "null");
		}
		else if (obj instanceof Integer || obj instanceof Long) {
			return literal(obj.toString(), "int");
		}
		else if (obj instanceof Boolean) { 
			return literal(obj.toString(), "bool");
		}
		else if (obj instanceof String) {
			return literal((String) obj, "string");
		}
		else if (obj instanceof Geometry) {
			throw new RuntimeException("Geo type not known by NLP engine");
		}
		else if (obj instanceof LocalDate) {
			throw new RuntimeException("LocalDate type not known by NLP engine");
		}
		else if (obj instanceof Instant) {
			throw new RuntimeException("Instant type not known by NLP engine");
		}
		else if (obj instanceof UUID) {
			return literal(obj.toString(), "uuid");
			
		}
		else
			throw new RuntimeException("Query executor does not know how to serialize object of type " +obj.getClass());
	}
	
	
	private static Map<String, String> serializeCommandValues(Map<String, Object> values) {
		HashMap<String, String> result = new HashMap<>();
		values.forEach((k,v)-> {
			if (v instanceof String || v instanceof UUID) {
				result.put(k, v.toString());
			}
		});
		return result;
	}
	
	public void process(String query, Map<String, Binding> bindings) {
		new UpdateExecutor(store, script, uuids, bindings, () -> "NLP process: " + query) {

            @Override
            protected void performUpdate(Map<String, Object> values) {
                String json = replaceInUpdateJson(query, values);
                
                // TODO this is a workaround to overcome the fact that
                // the NLP engine is blocking
                backgroundTask.execute(() -> doPost("processText", json));
            }
		}.scheduleUpdate();	
	}
	
	public void query(String query, Map<String, Binding> bindings, List<Path> signature) {
		new QueryExecutor(store, script, uuids, bindings, signature, () -> "NLP query: " + query) {
			@Override
			protected ResultIterator performSelect(Map<String, Object> values) {
				String json = replaceInQueryJson(query, values);
				String r = doPost("queryTextAnalytics", json);
				try {
					JsonNode resultsNode = MAPPER.readTree(r);
					return new NlpIterator(resultsNode);
				} catch (JsonProcessingException e) {
					throw new RuntimeException("Wrong response from NLAE engine");
				}
				
			}

		}.scheduleSelect(NLP_REPOSITORY);
	}
	
	public void delete(String query, Map<String, Binding> bindings) {
		new UpdateExecutor(store, script, uuids, bindings, () -> "NLP delete: " + query) {

            @Override
            protected void performUpdate(Map<String, Object> values) {
                String json = replaceInUpdateJson(query, values);
                doPost("deleteDocument", json);
					
            }
		}.scheduleUpdate();
	}
	
	private String replaceInQueryJson(String query, Map<String, Object> values) {
		Map<String, String> serialized = serializeExpression(values);
		logger.trace("Replacing parameters in: {} to: {} (from: {})", query, serialized, values);
		return new StringSubstitutor(serialized).replace(query);
	}

	
	protected String replaceInUpdateJson(String query, Map<String, Object> values) {
		Map<String, String> serialized = serializeCommandValues(values);
		logger.trace("Replacing parameters in: {} to: {} (from: {})", query, serialized, values);
		return new StringSubstitutor(serialized).replace(query);
	}
	
	private String doPost(String path, String body) {
		URI uri;
		try {
			uri = new URI("http://"+host+ ":" +port + "/" + path);
		} catch (URISyntaxException e) {
			throw new RuntimeException("Malformed URI to call NLAE");
		}
		logger.debug("Preparing NLP to {} containing: {}", uri, body);
		HttpClientBuilder httpClientBuilder = HttpClientBuilder.create();
		if (user != null && password != null) {
			CredentialsProvider credentialsProvider = new BasicCredentialsProvider();
			credentialsProvider.setCredentials(AuthScope.ANY, new UsernamePasswordCredentials(user, password));
			httpClientBuilder.setDefaultCredentialsProvider(credentialsProvider).build();
		}
		CloseableHttpClient httpClient = httpClientBuilder.build();
		HttpPost httpPost = new HttpPost(uri);
		httpPost.setEntity(new StringEntity(body, ContentType.APPLICATION_JSON));
		
		logger.debug("Sending request", httpPost);
		try (CloseableHttpResponse response = httpClient.execute(httpPost)) {
			if (response.getStatusLine() != null) {
				int status = response.getStatusLine().getStatusCode();
				if (status != HttpStatus.SC_OK) {
					logger.error("NLP engine returned error: {}", response.getStatusLine());
					throw new RuntimeException("Problem with the HTTP connection to the NLAE: Status was " + status);
				}
			}

			HttpEntity responseBody = response.getEntity();
			if (responseBody == null) {
				return null;
			}
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            responseBody.writeTo(baos);
            String result = baos.toString(getEncoding(responseBody));
            logger.debug("Got NLP response: {}", result);
            return result; 
		} catch (IOException e1) {
			logger.error("Failure to send data to nlp", e1);
			throw new RuntimeException("Problem connecting with NLAE", e1);
		}
		
		
	}

	private String getEncoding(HttpEntity responseBody) {
		Header responseEncoding = responseBody.getContentEncoding();
		if (responseEncoding != null) {
			String targetEncoding = responseEncoding.getValue();
			if (targetEncoding == null || "".equals(targetEncoding)) {
				logger.debug("Got empty encoding, so assuming utf8");
			}
			else if (!Charset.isSupported(targetEncoding)){
				logger.debug("Unknown charset: {}", targetEncoding);
			}
			else {
				return targetEncoding;
			}
		}
		return StandardCharsets.UTF_8.name();
	}

	public static void main(String[] args) throws SQLException {
		List<Consumer<List<Record>>> script = new ArrayList<Consumer<List<Record>>>();
		
		Map<String, UUID> uuids = new HashMap<>();
		uuids.put("f_0", UUID.randomUUID());
		
		ResultStore rs = new ResultStore(new HashMap<String, InputStream>());
		
		TyphonSessionState ts = new TyphonSessionState();
		Connection conn1 = BackendTestCommon.getConnection("localhost", 3306, "Inventory", "root", "XeNnEybEFjSe5aLy");
		
		MariaDBEngine mariaEngine = new MariaDBEngine(rs, ts, script, uuids, () -> conn1);
		
		mariaEngine.executeSelect("Inventory", "select `f`.`Foundation.@id` as `f.Foundation.@id`, `f`.`Foundation.mission` as `f.Foundation.mission`, `junction_NLP___$0`.`Foundation___NLP.unknown` as `f.Foundation.NLP___` from `Foundation` as `f` left outer join `Foundation.NLP___-Foundation___NLP.unknown` as `junction_NLP___$0` on (`junction_NLP___$0`.`Foundation.NLP___`) = (`f`.`Foundation.@id`);", 
				Arrays.asList(new Path("Inventory", "f", "Foundation", new String[] { "@id" }),
						new Path("Inventory", "f", "Foundation", new String[] { "mission" }),
						new Path("Inventory", "f", "Foundation", new String[] { "NLP___" })));
		
		NlpEngine engine = new NlpEngine(rs, 
				ts, script, uuids, "localhost", 8889, null, null);
		//engine.process("{ \"id\": \"e757fd4f-edc4-3e82-9bb8-1b1b466a0947\", \"entityType\": \"Company\", \"fieldName\": \"vision\", \"text\": \"More machines\", \"nlpFeatures\": [\"SentimentAnalysis\"], \"workflowNames\": [\"eng_spa\"]}", new HashMap<>());
		
		Map<String, Binding> bs = new HashMap<>();
		bs.put("f_0", new Field("Inventory","f","Foundation", "@id"));
		
		engine.query("{\n  \"from\": { \"entity\" : \"Foundation\", \"named\" : \"f\"},\n  \"with\": [{ \"path\": \"f.mission.SentimentAnalysis\", \"workflow\": \"eng_spa\"},{ \"path\": \"f.mission.NamedEntityRecognition\", \"workflow\": \"eng_ner\"}],\n  \"select\": [\"f.@id\",\"f.mission.SentimentAnalysis.Sentiment\",\"f.mission.NamedEntityRecognition.NamedEntity\"],\n  \"where\": {\"binaryExpression\": {\"op\": \"&&\", \"lhs\": {\"binaryExpression\": {\"op\": \"==\", \"lhs\": {\"attribute\": {\"path\": \"f.@id\"}}, \"rhs\": ${f_0} }}, \"rhs\": {\"binaryExpression\": {\"op\": \"&&\", \"lhs\": {\"binaryExpression\": {\"op\": \">=\", \"lhs\": {\"attribute\": {\"path\": \"f.mission.SentimentAnalysis.begin\"}}, \"rhs\": {\"literal\": {\"value\" : \"1\", \"type\" : \"int\"}} }}, \"rhs\": {\"binaryExpression\": {\"op\": \">=\", \"lhs\": {\"attribute\": {\"path\": \"f.mission.NamedEntityRecognition.begin\"}}, \"rhs\": {\"literal\": {\"value\" : \"2\", \"type\" : \"int\"}} }} }} }}\n}", bs, 
				Arrays.asList(
						new Path("Foundation", "foundation___NLP_0__f", "Foundation___NLP", new String[] { "@id" }),
						new Path("Foundation", "foundation___NLP_0__f", "Foundation___NLP", new String[] { "mission$SentimentAnalysis$Sentiment" }),
						new Path("Foundation", "foundation___NLP_0__f", "Foundation___NLP", new String[] { "mission$NamedEntityRecognition$NamedEntity" })
					));
		
		Runner.executeUpdates(script);
		
		//[<"Inventory","f","Foundation",["@id"]>
		//,<"Inventory","f","Foundation",["mission"]>,
		//<"Foundation","foundation___NLP_0__f","Foundation___NLP",["mission$SentimentAnalysis$Sentiment"]>,
		//<"Foundation","foundation___NLP_0__f","Foundation___NLP",["mission$NamedEntityRecognition$NamedEntity"]>]
		ResultTable rt = Runner.computeResultTable(script, Arrays.asList(
				new Path("Inventory", "f", "Foundation", new String[] {"@id"}),
				new Path("Inventory", "f", "Foundation", new String[] {"mission"}),
				new Path("Foundation", "foundation___NLP_0__f", "Foundation___NLP", new String[] {"mission$SentimentAnalysis$Sentiment"}),
				new Path("Foundation", "foundation___NLP_0__f", "Foundation___NLP", new String[] {"mission$NamedEntityRecognition$NamedEntity"})));
		System.out.println(rt);
	
	}

}
