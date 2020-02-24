import static org.junit.jupiter.api.Assertions.*;
import java.lang.reflect.Constructor;
import org.junit.jupiter.api.Test;
import nl.cwi.swat.typhonql.client.DatabaseInfo;

class VerifyQLClassCompilation {

	@Test
	void test() {
		Constructor<?>[] cons = DatabaseInfo.class.getConstructors();
		for (Constructor<?> c : cons) {
			if (c.getParameterCount() > 0) {
				assertFalse(c.getParameters()[0].getName().startsWith("arg"), "Make sure ql is compiled with parameter names");
			}
		}
		
	}

}
