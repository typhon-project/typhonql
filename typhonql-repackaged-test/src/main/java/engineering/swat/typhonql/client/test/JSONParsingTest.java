package engineering.swat.typhonql.client.test;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.net.URISyntaxException;

import nl.cwi.swat.typhonql.workingset.WorkingSet;
import nl.cwi.swat.typhonql.workingset.json.WorkingSetJSON;

public class JSONParsingTest {
	public static void main(String[] args) throws IOException, URISyntaxException {
		
		String json = "{\"Product\":[{\"uuid\":\"3522ad60-f069-4769-8c6e-6bf8aefa7020\",\"fields\":{\"reviews\":[{\"ref\":\"cfa12ffb-7eca-4585-bd2a-7b2f0ab35b60\"}],\"name\":\"Radio\",\"description\":\"Wireless\"},\"type\":\"Product\"}]}";
		
		WorkingSet ws = WorkingSetJSON.fromJSON(new ByteArrayInputStream(json.getBytes()));
		
		System.out.println("Parsed WS");
		System.out.println(ws);
		System.out.println("END parsed WS");
		
		

	}
}
