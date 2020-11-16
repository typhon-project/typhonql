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

package nl.cwi.swat.typhonql;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;

import org.apache.http.HttpEntity;
import org.apache.http.HttpStatus;
import org.apache.http.auth.AuthScope;
import org.apache.http.auth.UsernamePasswordCredentials;
import org.apache.http.client.CredentialsProvider;
import org.apache.http.client.methods.CloseableHttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.client.utils.URIBuilder;
import org.apache.http.entity.ContentType;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.BasicCredentialsProvider;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClientBuilder;
import org.rascalmpl.interpreter.utils.RuntimeExceptionFactory;
import org.rascalmpl.values.ValueFactoryFactory;

import com.fasterxml.jackson.core.JsonFactory;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import io.usethesource.vallang.IBool;
import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.IInteger;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IMapWriter;
import io.usethesource.vallang.ISourceLocation;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeFactory;
import io.usethesource.vallang.type.TypeStore;

public class TyphonQL {

	private final IValueFactory vf;
	private final TypeFactory tf;
	private final TypeStore ts = new TypeStore();
		
	public TyphonQL(IValueFactory vf, TypeFactory tf) {
		this.vf = vf;
		this.tf = tf;
	}
	
	public TyphonQL(IValueFactory vf) {
		this.vf = vf;
		this.tf = TypeFactory.getInstance();
	}
	
	public IString readHttpModel(ISourceLocation path, IString user, IString password) {
		URI uri = buildUri(path.getURI(), "/api/model/ml");
		String json = doGet(uri, user.getValue(), password.getValue());
		try {
			JsonNode array = new ObjectMapper(new JsonFactory()).readTree(json);
            return vf.string(array.get(0).get("contents").textValue());
		} catch (JsonProcessingException e) {
			throw new RuntimeException(e);
		}  
	}
	
	public IBool executeResetDatabases(ISourceLocation path, IString user, IString password) {
		URI uri = buildUri(path.getURI(), "/api/resetdatabases");
		String isReset = doGet(uri, user.getValue(), password.getValue());
		return vf.bool(Boolean.parseBoolean(isReset));
	}
	
	public IString executeQuery(ISourceLocation path, IString user, IString password, IString query) {
		URI uri = buildUri(path.getURI(), "/api/query");
		return vf.string(doPost(uri, user.getValue(), password.getValue(), query.getValue()));
	}
	
	public void executeDDLUpdate(ISourceLocation path, IString user, IString password, IString query) {
		URI uri = buildUri(path.getURI(), "/api/ddl");
		doPost(uri, user.getValue(), password.getValue(), query.getValue());
	}
	
	public void executeUpdate(ISourceLocation path, IString user, IString password, IString query) {
		URI uri = buildUri(path.getURI(), "/api/update");
		doPost(uri, user.getValue(), password.getValue(), query.getValue());
	}
	
	private URI buildUri(URI base, String path) {
		URIBuilder builder = new URIBuilder(base);
		builder.setPath(path);
		try {
			return builder.build();
		} catch (URISyntaxException e1) {
			throw new RuntimeException(e1);
		}
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
			e1.printStackTrace();
			throw RuntimeExceptionFactory.io(vf.string("Problem executing HTTP request"), null, null);
		} 
		
		if (response1.getStatusLine() != null) {
			if (response1.getStatusLine().getStatusCode() != HttpStatus.SC_OK)
				throw RuntimeExceptionFactory.io(
						vf.string("Problem with the HTTP connection to the polystore: Status was " + response1.getStatusLine().getStatusCode()), null, null);
		}
		
		try {
			HttpEntity entity1 = response1.getEntity();
			ByteArrayOutputStream baos = new ByteArrayOutputStream();
			entity1.writeTo(baos);
			String s = new String(baos.toByteArray());
			return s;

		} catch (IOException e) {
			e.printStackTrace();
			throw RuntimeExceptionFactory.io(vf.string("Problem reading from HTTP resource"), null, null);
		} finally {
			try {
				response1.close();
			} catch (IOException e) {
				e.printStackTrace();
				throw RuntimeExceptionFactory.io(vf.string("Problem closing HTTP resource"), null, null);
			}
		}
	}
	
	private String doPost(URI path, String user, String password, String body) {
		CredentialsProvider credentialsProvider = new BasicCredentialsProvider();
		credentialsProvider.setCredentials(AuthScope.ANY, new UsernamePasswordCredentials(user, password));
		CloseableHttpClient httpclient = HttpClientBuilder.create().setDefaultCredentialsProvider(credentialsProvider).build();
		HttpPost httpPost = new HttpPost(path);
        httpPost.setEntity(new StringEntity(body, ContentType.APPLICATION_JSON));
		CloseableHttpResponse response1;
		try {
			response1 = httpclient.execute(httpPost);

		} catch (IOException e1) {
			e1.printStackTrace();
			throw RuntimeExceptionFactory.io(vf.string("Problem executing HTTP request"), null, null);
		}
		
		if (response1.getStatusLine() != null) {
			if (response1.getStatusLine().getStatusCode() != HttpStatus.SC_OK)
				throw RuntimeExceptionFactory.io(
						vf.string("Problem with the HTTP connection to the polystore: Status was " + response1.getStatusLine().getStatusCode()), null, null);
		}
		
		try {
			HttpEntity entity1 = response1.getEntity();
			ByteArrayOutputStream baos = new ByteArrayOutputStream();
			entity1.writeTo(baos);
			String s = new String(baos.toByteArray());
			return s;

		} catch (IOException e) {
			e.printStackTrace();
			throw RuntimeExceptionFactory.io(vf.string("Problem reading from HTTP resource"), null, null);
		} finally {
			try {
				response1.close();
			} catch (IOException e) {
				e.printStackTrace();
				throw RuntimeExceptionFactory.io(vf.string("Problem closing HTTP resource"), null, null);
			}
		}
	}
	
	public IMap readConnectionsInfo(IString host, IInteger port, IString user, IString password) throws URISyntaxException {
		URI uri = new URI("http://" + host.getValue() + ":" + port.intValue());
		return readConnectionsInfo(vf.sourceLocation(uri), user, password);
	}
	
	public IMap readConnectionsInfo(ISourceLocation path, IString user, IString password) throws URISyntaxException {
		URI uri = buildUri(path.getURI(), "/api/databases");
		String json = doGet(uri, user.getValue(), password.getValue());
		JsonNode array;
		try {
			array = new ObjectMapper(new JsonFactory()).readTree(json);
		} catch (JsonProcessingException e1) {
			throw new RuntimeException(e1);
		}
		IMapWriter mw = vf.mapWriter();
		array.iterator().forEachRemaining(d -> {
			try {
				String dbName = d.get("name").textValue();
				IConstructor info = buildConnectionInfo(
					d.get("externalHost").textValue(),
					d.get("externalPort").intValue(), 
					d.get("dbType").textValue().toLowerCase(),
					!d.has("username") ? null : d.get("username").textValue(),
					!d.has("password") ? null : d.get("password").textValue());
				mw.put(vf.string(dbName), info);
			} catch (UnsupportedOperationException e) {
				// skipping unsupported technology for now
			}
		});
		return mw.done();
	}


	private IConstructor buildConnectionInfo(String host, int port, String dbType, String user,
			String password) {
		Type adtType = tf.abstractDataType(ts, "Connection");
		Type connectionType = null;
		
        switch (dbType) {
        case "mongodb":
        	connectionType = tf.constructor(ts, adtType, "mongoConnection", tf.stringType(), "host", tf.integerType(), "port", tf.stringType(), "user", tf.stringType(), "password");
        	break;
        case "mariadb":
        	connectionType =tf.constructor(ts, adtType, "mariaConnection", tf.stringType(), "host", tf.integerType(), "port", tf.stringType(), "user", tf.stringType(), "password");
        	break;
        case "cassandra":
        	connectionType =tf.constructor(ts, adtType, "cassandraConnection", tf.stringType(), "host", tf.integerType(), "port", tf.stringType(), "user", tf.stringType(), "password");
        	break;
        case "neo4j":
        	connectionType =tf.constructor(ts, adtType, "neoConnection", tf.stringType(), "host", tf.integerType(), "port", tf.stringType(), "user", tf.stringType(), "password");
        	break;
        case "nlae":
        	connectionType =tf.constructor(ts, adtType, "nlpConnection", tf.stringType(), "host", tf.integerType(), "port", tf.stringType(), "user", tf.stringType(), "password");
        	break;
        }
        return vf.constructor(connectionType, vf.string(host), vf.integer(port), vf.string(user), vf.string(password));
	}

	public static void main(String[] args) throws URISyntaxException, IOException {
		IValueFactory vf = ValueFactoryFactory.getValueFactory();
		TyphonQL ql = new TyphonQL(vf);
		//IMap ws = ql.executeQuery(vf.sourceLocation(URI.create("http://localhost:8080")), vf.string("pablo"), vf.string("antonio"), vf.string("from Product p select p"));
		//IBool reset = ql.executeResetDatabases(vf.sourceLocation(URI.create("http://localhost:8080")), vf.string("pablo"), vf.string("antonio"));
		//System.out.println(reset);
		//System.out.println(ws);
		
		IMap  m = ql.readConnectionsInfo(vf.string("localhost"), vf.integer(8080), vf.string("admin"), vf.string("admin1@"));
		System.out.println(m);
		IString t = ql.executeQuery(vf.sourceLocation(new URI("http://localhost:8080")),
				vf.string("admin"), vf.string("admin1@"), vf.string("from User u select u"));
		
		System.out.println(t);
	}

}
