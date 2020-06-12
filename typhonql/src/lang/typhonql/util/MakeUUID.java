package lang.typhonql.util;

import java.nio.charset.StandardCharsets;
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
	
	public IString hashUUID(IString key) {
		UUID uuid = UUID.nameUUIDFromBytes(key.getValue().getBytes(StandardCharsets.UTF_8));
		return vf.string(uuid.toString());
	}	

	public static String randomUUID() {
		return UUID.randomUUID().toString();
	}
	

	
}
