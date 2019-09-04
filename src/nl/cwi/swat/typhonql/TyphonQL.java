package nl.cwi.swat.typhonql;

import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.EPackage;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.xtext.resource.XtextResourceSet;
import org.rascalmpl.interpreter.TypeReifier;

import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.ISourceLocation;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeStore;
import lang.ecore.bridge.Convert;
import typhonml.TyphonmlPackage;

public class TyphonQL {

	private final IValueFactory vf;
	private final TypeReifier tr;
	private final XtextResourceSet xtextRS;
		
		
	public TyphonQL(IValueFactory vf) {
		this.vf = vf;
		this.tr = new TypeReifier(vf);
		//Resource.Factory.Registry.INSTANCE.getExtensionToFactoryMap().put("xmi", new XMIResourceFactoryImpl());
		EPackage.Registry.INSTANCE.put(TyphonmlPackage.eNS_URI, TyphonmlPackage.eINSTANCE);
		it.univaq.disim.typhon.TyphonMLStandaloneSetup.doSetup();
		xtextRS = new XtextResourceSet();
	}
		
	// TODO: we might have to delay returning the schema, since the platform
	// might not be ready when this code is run.
	public IConstructor bootTyphonQL(IValue typeOfTyphonML, ISourceLocation path) {
		Connections.boot();

		TypeStore ts = new TypeStore(); // start afresh
		
		Resource r = xtextRS.getResource(URI.createURI("file:///Users/tvdstorm/CWI/typhonml/it.univaq.disim.typhonml.xtext.examples/mydb.tml"), true);
		
		typhonml.Model m = (typhonml.Model)r.getContents().get(0);
		System.out.println(m);
		
		Type rt = tr.valueToType((IConstructor) typeOfTyphonML, ts);
		Convert.declareRefType(ts);
		Convert.declareMaybeType(ts);
		return (IConstructor) Convert.obj2value(m, rt, vf, ts, vf.sourceLocation("file:///Users/tvdstorm/CWI/typhonml/it.univaq.disim.typhonml.xtext.examples/mydb.tml"));
		
	}
	
}
