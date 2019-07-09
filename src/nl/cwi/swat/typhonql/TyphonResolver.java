package nl.cwi.swat.typhonql;

import org.rascalmpl.uri.libraries.ClassResourceInput;

import lang.typhonql.Dummy;

public class TyphonResolver extends ClassResourceInput {
	public TyphonResolver() {
		super("typhon", Dummy.class, "/");
	}
}
