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

package engineering.swat.typhonql.client.test;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.ArrayList;
import java.util.List;

import org.apache.http.HttpEntity;
import org.apache.http.HttpStatus;
import org.apache.http.auth.AuthScope;
import org.apache.http.auth.UsernamePasswordCredentials;
import org.apache.http.client.CredentialsProvider;
import org.apache.http.client.methods.CloseableHttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.utils.URIBuilder;
import org.apache.http.impl.client.BasicCredentialsProvider;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClientBuilder;
import org.bson.BsonArray;
import org.bson.BsonDocument;
import org.bson.BsonInvalidOperationException;
import org.bson.BsonValue;

import nl.cwi.swat.typhonql.client.DatabaseInfo;

public class PolystoreAPIHelper {
	public static String readHttpModel(String host, int port, String user, String password) throws URISyntaxException {
		URI uri = new URI("http://" + host + ":" + port);
		return readHttpModel(uri, user, password);
	}
	
	public static String readHttpModel(URI path, String user, String password) {
		URI uri = buildUri(path, "/api/models/ml");
		String json = doGet(uri, user, password);
		BsonArray array = BsonArray.parse(json);
		String contents = array.get(0).asDocument().getString("contents").getValue();
		return contents;
	}

	private static URI buildUri(URI base, String path) {
		URIBuilder builder = new URIBuilder(base);
		builder.setPath(path);
		try {
			return builder.build();
		} catch (URISyntaxException e1) {
			throw new RuntimeException(e1);
		}
	}

	private static String doGet(URI path, String user, String password) {
		CredentialsProvider credentialsProvider = new BasicCredentialsProvider();
		credentialsProvider.setCredentials(AuthScope.ANY, new UsernamePasswordCredentials(user, password));
		CloseableHttpClient httpclient = HttpClientBuilder.create().setDefaultCredentialsProvider(credentialsProvider).build();
		HttpGet httpGet = new HttpGet(path);
		
		CloseableHttpResponse response1 = null;
		try {
			response1 = httpclient.execute(httpGet);
		} catch (IOException e1) {
			throw new RuntimeException("Problem executing GET", e1);
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
			throw new  RuntimeException("Problem reading from HTTP resource");
		} finally {
			try {
				response1.close();
			} catch (IOException e) {
				e.printStackTrace();
				throw new RuntimeException("Problem closing HTTP resource");
			}
		}
	}
	
	public static List<DatabaseInfo> readConnectionsInfo(String host, int port, String user, String password) throws URISyntaxException {
		URI uri = new URI("http://" + host + ":" + port);
		return readConnectionsInfo(uri, user, password);
	}
	
	
	public static List<DatabaseInfo> readConnectionsInfo(URI path, String user, String password) throws URISyntaxException {
		URI uri = buildUri(path, "/api/databases");
		String json = doGet(uri, user, password);

		BsonArray array = BsonArray.parse(json);
		List<DatabaseInfo> lst = new ArrayList<DatabaseInfo>();
		for (BsonValue v : array.getValues()) {
			BsonDocument d = v.asDocument();
			try {
				DatabaseInfo info = new DatabaseInfo(d.getString("externalHost").getValue(),
						d.getNumber("externalPort").intValue(), 
						d.getString("name").getValue(),
						d.getString("dbType").getValue(),
						d.getString("dbType").getValue(),
						d.getString("username").getValue(),
						d.getString("password").getValue());
				lst.add(info);
			} catch (BsonInvalidOperationException e) {
				// TODO not do anything if row of connection information is unparsable
			}
		}
		return lst;
	}

}
