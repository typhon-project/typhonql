package nl.cwi.swat.typhonql;

import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.xmi.impl.XMIResourceFactoryImpl;
import org.rascalmpl.interpreter.TypeReifier;

import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;

public class TyphonQL {

	private final IValueFactory vf;
	private final TypeReifier tr;
	private typhonml.Model model;
		
		
	public TyphonQL(IValueFactory vf) {
		this.vf = vf;
		this.tr = new TypeReifier(vf);

		Resource.Factory.Registry.INSTANCE.getExtensionToFactoryMap().put("*", new XMIResourceFactoryImpl());
	}
		
	// TODO: we might have to delay returning the schema, since the platform
	// might not be ready when this code is run.
	public void bootTyphonQL(IValue typeOfTyphonML) {
		//TypeStore ts = new TypeStore(); // start afresh
		
		Connections.boot();
		
		
		
		//model = loadTyphonMLModel(); 
//		
//		
//		Type rt = tr.valueToType((IConstructor) typeOfTyphonML, ts);
//		Convert.declareRefType(ts);
//		Convert.declareMaybeType(ts);
//		return Convert.obj2value(model, rt, vf, ts, null /* todo: some loc */);
		
		//return vf.integer(0);
	}
	
//	public static void main(String[] args) {
//		System.out.println(loadTyphonMLModel());
//	}
	
	
//	private  Model loadTyphonMLModel() {
//		TyphonmlPackage.eINSTANCE.getClass(); // trigger registration 
//		HttpURLConnection connection = null;
//		try {
//			ResourceSet rs = new ResourceSetImpl();
//			
//			URL webURL = new URL("http://localhost:8080/model");
//
//			EPackage.Registry packageRegistry = rs.getPackageRegistry();
//			packageRegistry.put(TyphonmlPackage.eNS_URI, TyphonmlPackage.eINSTANCE);
//
//			URI emfURI = URI.createURI(webURL.toString());
//			Resource res = rs.getResource(emfURI, true);
//			connection = (HttpURLConnection) webURL.openConnection();
//			connection.setRequestMethod("GET");
//
//			res.load(connection.getInputStream(), Collections.emptyMap());
//			//Resource res = Convert.loadResource(vf.sourceLocation(webURL.toURI()));
//			return (Model) res.getContents().get(0);
//		} 
//		catch (IOException e) {
//			// TODO Auto-generated catch block
//			e.printStackTrace();
//		}
//		finally {
//			if (connection != null) {
//				connection.disconnect();
//			}
//		}
//		return null;
//	}
//		
//	private String loadModel() {
//		HttpURLConnection connection = null;
//		try {
//			URL url = new URL("http://localhost:8080/model");
//			connection = (HttpURLConnection) url.openConnection();
//			connection.setRequestMethod("GET");
//
//			//Send request
////			DataOutputStream wr = new DataOutputStream (connection.getOutputStream());
////			//wr.writeBytes(urlParameters);
////			wr.close();
//
//			//Get Response  
//			InputStream is = connection.getInputStream();
//			BufferedReader rd = new BufferedReader(new InputStreamReader(is));
//			StringBuilder response = new StringBuilder(); // or StringBuffer if Java version 5+
//			String line;
//			while ((line = rd.readLine()) != null) {
//				response.append(line);
//				response.append('\r');
//			}
//			rd.close();
//			return response.toString();
//	  } catch (Exception e) {
//	    e.printStackTrace();
//	    return null;
//	  } finally {
//	    if (connection != null) {
//	      connection.disconnect();
//	    }
//	  }
//	}
}
