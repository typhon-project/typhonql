package nl.cwi.swat.typhonql;

import java.io.PrintWriter;
import java.util.Arrays;

import org.eclipse.core.runtime.Platform;
import org.eclipse.emf.ecore.EPackage;
import org.eclipse.emf.ecore.EPackage.Registry;
import org.osgi.framework.Bundle;
import org.rascalmpl.eclipse.nature.BundleClassLoader;
import org.rascalmpl.interpreter.Evaluator;
import org.rascalmpl.interpreter.env.GlobalEnvironment;
import org.rascalmpl.interpreter.env.ModuleEnvironment;
import org.rascalmpl.interpreter.load.RascalSearchPath;
import org.rascalmpl.uri.URIUtil;
import org.rascalmpl.values.ValueFactoryFactory;

import io.usethesource.vallang.IValueFactory;

public class Compiler {
	
	// Abstraction over all the Rascal stuff
	// Singleton
	
	private static final Compiler instance = new Compiler();
	
	public static Compiler getInstance() {
		return instance;
	}

	private Evaluator eval;
	private IValueFactory vf;
	
	private Compiler() {
		GlobalEnvironment heap = new GlobalEnvironment();
		ModuleEnvironment env = new ModuleEnvironment("typhon", heap);
		vf = ValueFactoryFactory.getValueFactory();
		RascalSearchPath rsp = new RascalSearchPath();
		eval = new Evaluator(vf, new PrintWriter(System.err), new PrintWriter(System.out), env, heap, Arrays.asList(), rsp);
		eval.addRascalSearchPath(URIUtil.rootLocation("typhon"));
		eval.addRascalSearchPath(URIUtil.rootLocation("std"));
		eval.addRascalSearchPath(URIUtil.rootLocation("ecore"));
		
		eval.doImport(null, "IO");
		// value factory
		// interpreter
		// imports of modules
	}
	
	public static void main(String[] args) {
		Compiler c = Compiler.getInstance();
		System.out.println(c.eval.eval(null, "1+2", c.vf.sourceLocation("cwd:///")));
		System.out.println(c.eval.eval(null, "dummy()", c.vf.sourceLocation("cwd:///")));
		Registry x = EPackage.Registry.INSTANCE;
		x.put("http://org.typhon.dsls.typhonml.sirius", typhonml.TyphonmlPackage.eINSTANCE);
		EPackage pkg = x.getEPackage("http://org.typhon.dsls.typhonml.sirius");
		System.out.println(pkg);
	}
	
	
	// methods to compile
	

}
