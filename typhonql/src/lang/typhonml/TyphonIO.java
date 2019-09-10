package lang.typhonml;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;

import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.xmi.impl.XMIResourceFactoryImpl;
import org.rascalmpl.interpreter.IEvaluatorContext;
import org.rascalmpl.values.ValueFactoryFactory;

import io.usethesource.vallang.ISourceLocation;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.TypeStore;
import lang.ecore.bridge.Convert;
import lang.ecore.bridge.IO;

public class TyphonIO {
	private final IO io;
	
	/*
	 * Public Rascal interface
	 */
	
	public TyphonIO(IValueFactory vf) {
		this.io = new IO(vf);
	}
	
	public IValue loadTyphon(IValue reifiedType, IString input, ISourceLocation refBase, IEvaluatorContext ctx) {
		return io.load(reifiedType, input, refBase, typhonml.TyphonmlPackage.eINSTANCE, ctx);
	}
	
	public static void main(String[] as) throws IOException {
		IValueFactory vf = ValueFactoryFactory.getValueFactory();
		Resource.Factory.Registry.INSTANCE.getExtensionToFactoryMap().put("*", new XMIResourceFactoryImpl());
		TypeStore ts = new TypeStore(); // start afresh
		ISourceLocation refBase = vf.sourceLocation(java.net.URI.create("http://pablo:antonio@localhost:8080/api/models/ml"));
		IString input = vf.string(
				new String(Files.readAllBytes(Paths.get("/Users/pablo/git/typhonql/typhonql/src/lang/typhonml/mydb4.xmi")))
		);
		System.out.println(refBase);
		Convert.declareMaybeType(ts);
		EObject root = Convert.loadResource(refBase, input, typhonml.TyphonmlPackage.eINSTANCE).getContents().get(0);

		//Convert.obj2value(root, rt, vf, ts, refBase);
		/*TreeIterator<EObject> os = root.eAllContents();
		while (os.hasNext()) {
			System.out.println(os.next());
		}
		*/
		
	}
}
