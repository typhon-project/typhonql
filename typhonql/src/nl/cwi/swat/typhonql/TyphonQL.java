package nl.cwi.swat.typhonql;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.apache.http.HttpEntity;
import org.apache.http.HttpStatus;
import org.apache.http.auth.AuthScope;
import org.apache.http.auth.UsernamePasswordCredentials;
import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.CredentialsProvider;
import org.apache.http.client.methods.CloseableHttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.utils.URIBuilder;
import org.apache.http.impl.client.BasicCredentialsProvider;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClientBuilder;
import org.apache.http.impl.client.HttpClients;
import org.bson.BsonArray;
import org.bson.BsonDocument;
import org.bson.BsonInvalidOperationException;
import org.bson.BsonValue;
import org.eclipse.emf.ecore.EPackage;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.xmi.impl.XMIResourceFactoryImpl;
import org.rascalmpl.interpreter.TypeReifier;
import org.rascalmpl.interpreter.utils.RuntimeExceptionFactory;

import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.ISourceLocation;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeStore;
import lang.ecore.bridge.Convert;
import typhonml.TyphonmlPackage;

public class TyphonQL {

	private final IValueFactory vf;
	private final TypeReifier tr;
		
		
	public TyphonQL(IValueFactory vf) {
		this.vf = vf;
		this.tr = new TypeReifier(vf);
		Resource.Factory.Registry.INSTANCE.getExtensionToFactoryMap().put("xmi", new XMIResourceFactoryImpl());
		EPackage.Registry.INSTANCE.put(TyphonmlPackage.eNS_URI, TyphonmlPackage.eINSTANCE);
		it.univaq.disim.typhon.TyphonMLStandaloneSetup.doSetup();
	}
		
	// TODO: we might have to delay returning the schema, since the platform
	// might not be ready when this code is run.
	public IConstructor bootTyphonQL(IValue typeOfTyphonML, ISourceLocation path) {
		//Connections.boot();

		TypeStore ts = new TypeStore(); // start afresh
		
		//Resource r = xtextRS.getResource(URI.createURI("file:///Users/tvdstorm/CWI/typhonql/src/newmydb4.xmi"), true);
		final ISourceLocation mydb = vf.sourceLocation("file:///Users/tvdstorm/CWI/typhonql/src/newmydb4.xmi");
		
		try {
			Resource r = Convert.loadResource(mydb);
			typhonml.Model m = (typhonml.Model)r.getContents().get(0);
			Type rt = tr.valueToType((IConstructor) typeOfTyphonML, ts);
			Convert.declareRefType(ts);
			Convert.declareMaybeType(ts);
			return (IConstructor) Convert.obj2value(m, rt, vf, ts, mydb);
		} catch (IOException e) {
			throw RuntimeExceptionFactory.io(vf.string(e.getMessage()), null, null);
		}
	}
	
	public void bootConnections(ISourceLocation path, IString user, IString password) {
		URI uri = buildUri(path.getURI(), "/api/databases");
		String json = readHttp(uri, user.getValue(), password.getValue());
		BsonArray array = BsonArray.parse(json);
		List<ConnectionInfo> infos = new ArrayList<ConnectionInfo>();
		for (BsonValue v : array.getValues()) {
			BsonDocument d = v.asDocument();
			try {
				String engineType = d.getString("engineType").getValue().toLowerCase() + "db";
				DBType dbType = DBType.valueOf(engineType);
				if (dbType == null)
					throw new RuntimeException("Engine type " + d.getString("engineType").getValue() + " not known");
				ConnectionInfo info = new ConnectionInfo(
					path.getURI().toString(),
					d.getString("host").getValue(), 
					d.getNumber("port").intValue(), 
					d.getString("name").getValue(), 
					dbType,
					d.getString("dbType").getValue(),
					d.getString("username").getValue(),
					d.getString("password").getValue());
				infos.add(info);
			} catch (BsonInvalidOperationException e) {
				// TODO not do anything if row of connection information is unparsable
			}
		}
		Connections.boot(infos.toArray(new ConnectionInfo[0]));
	}
	
	public IString readHttpModel(ISourceLocation path, IString user, IString password) {
		URI uri = buildUri(path.getURI(), "/api/models/ml");
		String json = readHttp(uri, user.getValue(), password.getValue());
		BsonArray array = BsonArray.parse(json);
		String contents = array.get(0).asDocument().getString("contents").getValue();
		return vf.string(contents);
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

	private String readHttp(URI path, String user, String password) {
		CredentialsProvider credentialsProvider = new BasicCredentialsProvider();
		credentialsProvider.setCredentials(AuthScope.ANY, new UsernamePasswordCredentials(user, password));
		CloseableHttpClient httpclient = HttpClientBuilder.create().setDefaultCredentialsProvider(credentialsProvider).build();
		HttpGet httpGet = new HttpGet(path);
		
		CloseableHttpResponse response1;
		try {
			response1 = httpclient.execute(httpGet);
		} catch (ClientProtocolException e1) {
			e1.printStackTrace();
			throw RuntimeExceptionFactory.io(vf.string("Problem executing HTTP request"), null, null);
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
	
}
