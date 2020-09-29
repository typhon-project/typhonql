package nl.cwi.swat.typhonql.backend.nlp;

import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Consumer;

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

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.fasterxml.jackson.databind.node.TextNode;

import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.Engine;
import nl.cwi.swat.typhonql.backend.QueryExecutor;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultIterator;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.UpdateExecutor;
import nl.cwi.swat.typhonql.backend.rascal.Path;
import nl.cwi.swat.typhonql.backend.rascal.TyphonSessionState;


public class NlpEngine extends Engine {
	
	public static final String NLP_REPOSITORY = "nlae";
	
	private final String host;
	private final int port;
	private final String user;
	private final String password;

	public NlpEngine(ResultStore store, TyphonSessionState state, List<Consumer<List<Record>>> script, Map<String, UUID> uuids,
			String host, int port, String user, String password) {
		super(store, state, script, uuids);
		this.host = host;
		this.port = port;
		this.user = user;
		this.password = password;
	}
	
	public void process(String query, Map<String, Binding> bindings) {
		new UpdateExecutor(store, script, uuids, bindings, () -> "NLP process: " + query) {

            @Override
            protected void performUpdate(Map<String, Object> values) {
                String json = replaceInJson(query, values, true);
                doPost("processText", json);
					
            }
		}.scheduleUpdate();	
	}
	
	public void query(String query, Map<String, Binding> bindings, List<Path> signature) {
		new QueryExecutor(store, script, uuids, bindings, signature, () -> "NLP query: " + query) {
			@Override
			protected ResultIterator performSelect(Map<String, Object> values) {
				return null;
			}

		}.scheduleSelect(NLP_REPOSITORY);
	}
	
	public void delete(String query, Map<String, Binding> bindings) {
		new UpdateExecutor(store, script, uuids, bindings, () -> "NLP delete: " + query) {

            @Override
            protected void performUpdate(Map<String, Object> values) {
                String json = replaceInJson(query, values, true);
                doPost("deleteDocument", json);
					
            }
		}.scheduleUpdate();
	}

	protected String replaceInJson(String query, Map<String, Object> values, boolean b) {
		ObjectMapper mapper = new ObjectMapper();
	    JsonNode node;
		try {
			node = mapper.readTree(query);
			if (!values.isEmpty()) {
		    	String id =node.get("id").asText().substring(1);
		    	if (values.containsKey(id)) {
		    		((ObjectNode)node).replace("id", TextNode.valueOf((String) values.get("id")));
		    	}
		    }
		    return mapper.writeValueAsString(node);
		} catch (JsonProcessingException e) {
			throw new RuntimeException("Error processing Json when processing NLP request", e);
		}
	}
	
	private void doPost(String path, String body) {
		URI uri;
		try {
			uri = new URI("http", host+ ":" +port, path);
		} catch (URISyntaxException e) {
			throw new RuntimeException("Malformed URI to call NLAE");
		}
		CredentialsProvider credentialsProvider = new BasicCredentialsProvider();
		credentialsProvider.setCredentials(AuthScope.ANY, new UsernamePasswordCredentials(user, password));
		CloseableHttpClient httpclient = HttpClientBuilder.create().setDefaultCredentialsProvider(credentialsProvider).build();
		HttpPost httpPost = new HttpPost(path);
		httpPost.setEntity(new StringEntity(body, ContentType.APPLICATION_JSON));
		
		CloseableHttpResponse response1;
		try {
			response1 = httpclient.execute(httpPost);

		} catch (IOException e1) {
			throw new RuntimeException("Problem connecting with NLAE");
		}
		
		if (response1.getStatusLine() != null) {
			if (response1.getStatusLine().getStatusCode() != HttpStatus.SC_OK)
				throw new RuntimeException("Problem with the HTTP connection to the NLAE: Status was " + response1.getStatusLine().getStatusCode());
		}
		
	}



}
