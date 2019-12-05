package engineering.swat.typhonql.client.test;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URISyntaxException;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import nl.cwi.swat.typhonql.workingset.Entity;
import nl.cwi.swat.typhonql.workingset.EntityRef;
import nl.cwi.swat.typhonql.workingset.WorkingSet;

public class JSONSerializingTest {
	public static void main(String[] args) throws IOException, URISyntaxException {
		
		Map<String, List<Entity>> map = new HashMap<String, List<Entity>>();
		Map<String, Object> fields = new HashMap<String, Object>();
		fields.put("review", new EntityRef("48c5bfe5-04ab-4a62-9106-90d21007ee30"));
		fields.put("age", 30);
		Entity e = new Entity("Person", "48c5bfe5-04ab-4a62-9106-90d21007ee29", fields);
		map.put("Person", Arrays.asList(e));
		
		WorkingSet ws = new WorkingSet(map);
		
		System.out.println(ws.get("Person").get(0).fields.get("review"));
		System.out.println(ws.get("Person").get(0).fields.get("age"));
		
		
		ByteArrayOutputStream baos = new ByteArrayOutputStream();
		WorkingSetJSON.toJSON(ws, baos);
		String json = new String(baos.toByteArray());
		
		WorkingSet ws0 = WorkingSetJSON.fromJSON(new ByteArrayInputStream(json.getBytes()));
		
		System.out.println(ws0.get("Person").get(0).fields.get("review"));
		System.out.println(ws.get("Person").get(0).fields.get("age"));

		System.out.println(json);
		
	
		
		

	}
}
