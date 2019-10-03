package lang.typhonql.util;

import java.util.UUID;

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

	public static String randomUUID() {
		return UUID.randomUUID().toString();
	}
	
	
}
