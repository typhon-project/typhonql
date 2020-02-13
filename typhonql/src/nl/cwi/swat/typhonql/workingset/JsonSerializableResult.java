package nl.cwi.swat.typhonql.workingset;

import java.io.IOException;
import java.io.OutputStream;

public interface JsonSerializableResult {
	void serializeJSON(OutputStream target) throws IOException;
}
