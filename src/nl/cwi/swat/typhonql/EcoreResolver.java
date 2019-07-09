package nl.cwi.swat.typhonql;

import org.rascalmpl.uri.libraries.ClassResourceInput;

public class EcoreResolver extends ClassResourceInput {

	public EcoreResolver() {
		super("ecore", lang.ecore.bridge.Convert.class, "/");
	}

}
