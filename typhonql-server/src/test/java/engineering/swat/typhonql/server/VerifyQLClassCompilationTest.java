package engineering.swat.typhonql.server;
import static org.junit.jupiter.api.Assertions.*;
import java.lang.reflect.Constructor;
import org.junit.jupiter.api.Test;
import nl.cwi.swat.typhonql.client.DatabaseInfo;

public class VerifyQLClassCompilationTest {

	@Test
	void checkArgNamesCompiled() {
		Constructor<?>[] cons = DatabaseInfo.class.getConstructors();
		for (Constructor<?> c : cons) {
			if (c.getParameterCount() > 0) {
				assertFalse(c.getParameters()[0].getName().equals("arg0"), "Make sure ql is compiled with parameter names");
			}
		}
		
	}

}
