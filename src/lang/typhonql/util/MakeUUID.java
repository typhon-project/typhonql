package lang.typhonql.util;

import java.util.UUID;

import org.eclipse.emf.ecore.EPackage;

import io.usethesource.vallang.IString;
import io.usethesource.vallang.IValueFactory;

public class MakeUUID {
	private final IValueFactory vf;
	
	
	
	public MakeUUID(IValueFactory vf) {
		this.vf = vf;
	}
	
	public IString makeUUID() {
		return vf.string(randomUUID());
	}
	
	
	@Deprecated
	public void registerTyphonML() {
		EPackage.Registry.INSTANCE.put("http://org.typhon.dsls.typhonml.sirius", typhonml.TyphonmlPackage.eINSTANCE);
	}

	public static String randomUUID() {
		return UUID.randomUUID().toString();
	}
	
	
}
