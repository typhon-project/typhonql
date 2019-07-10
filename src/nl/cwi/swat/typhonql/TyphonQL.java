package nl.cwi.swat.typhonql;

import java.util.Map;

import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.xmi.impl.XMIResourceFactoryImpl;
import org.rascalmpl.interpreter.TypeReifier;

import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.IList;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeStore;
import lang.ecore.bridge.Convert;

public class TyphonQL {

	private final IValueFactory vf;
	private final TypeReifier tr;
	private typhonml.Model model;
	private Map<String, Object> connections;
		
		
	public TyphonQL(IValueFactory vf) {
		this.vf = vf;
		this.tr = new TypeReifier(vf);

		Resource.Factory.Registry.INSTANCE.getExtensionToFactoryMap().put("*", new XMIResourceFactoryImpl());
	}
		
	// TODO: we might have to delay returning the schema, since the platform
	// might not be ready when this code is run.
	public IValue bootTyphonQL(IValue typeOfTyphonML) {
		TypeStore ts = new TypeStore(); // start afresh

		model = null; // todo: get it from the platform
		connections = null; // todo: get it from the platform
		
		Type rt = tr.valueToType((IConstructor) typeOfTyphonML, ts);
		Convert.declareRefType(ts);
		Convert.declareMaybeType(ts);
		return Convert.obj2value(model, rt, vf, ts, null /* todo: some loc */);
	}
	
	public IMap toMongoDB(IString dbName, IList calls) {
		return vf.map();
	}

	public IMap toSQL(IString dbName, IList statements) {
		return vf.map();
	}
		
}
