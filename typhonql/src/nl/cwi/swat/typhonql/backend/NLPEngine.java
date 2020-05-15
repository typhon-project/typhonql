package nl.cwi.swat.typhonql.backend;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

import org.apache.http.HttpEntity;
import org.apache.http.HttpStatus;
import org.apache.http.auth.AuthScope;
import org.apache.http.auth.UsernamePasswordCredentials;
import org.apache.http.client.CredentialsProvider;
import org.apache.http.client.methods.CloseableHttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.BasicCredentialsProvider;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClientBuilder;

import io.usethesource.vallang.IList;
import nl.cwi.swat.typhonql.backend.rascal.ConnectionData;

public class NLPEngine extends Engine {

	private ConnectionData connection;
	private URI uri;

	public NLPEngine(ResultStore store, List<Consumer<List<Record>>> script, List<Runnable> updates, Map<String, String> uuids, ConnectionData connection) throws URISyntaxException {
		super(store, script, updates, uuids);
		this.uri = new URI("http://" + connection.getHost() + ":" + connection.getPort());
	}

	public void sendRequests(IList requests, Map<String, Binding> bindingsMap) {
		//String json = doGet(uri, connection.getUser(), connection.getPassword());
		System.out.println("Simulating request to NLP server...");
	}
	
	private String doGet(URI path, String user, String password) {
		CredentialsProvider credentialsProvider = new BasicCredentialsProvider();
		credentialsProvider.setCredentials(AuthScope.ANY, new UsernamePasswordCredentials(user, password));
		CloseableHttpClient httpclient = HttpClientBuilder.create().setDefaultCredentialsProvider(credentialsProvider).build();
		HttpGet httpGet = new HttpGet(path);
		
		CloseableHttpResponse response1;
		try {
			response1 = httpclient.execute(httpGet);
		} catch (IOException e1) {
			throw new RuntimeException("Problem executing HTTP request");
		} 
		
		if (response1.getStatusLine() != null) {
			if (response1.getStatusLine().getStatusCode() != HttpStatus.SC_OK)
				throw new RuntimeException("Problem with the HTTP connection to the polystore: Status was " + response1.getStatusLine().getStatusCode());
		}
		
		try {
			HttpEntity entity1 = response1.getEntity();
			ByteArrayOutputStream baos = new ByteArrayOutputStream();
			entity1.writeTo(baos);
			String s = new String(baos.toByteArray());
			return s;

		} catch (IOException e) {
			e.printStackTrace();
			throw new RuntimeException("Problem reading from HTTP resource");
		} finally {
			try {
				response1.close();
			} catch (IOException e) {
				e.printStackTrace();
				throw new RuntimeException("Problem closing HTTP resource");
			}
		}
	}

}
