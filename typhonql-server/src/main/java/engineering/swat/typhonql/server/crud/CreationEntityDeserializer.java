package engineering.swat.typhonql.server.crud;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.DeserializationContext;
import com.fasterxml.jackson.databind.JsonDeserializer;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.fasterxml.jackson.databind.node.TextNode;

public class CreationEntityDeserializer extends JsonDeserializer<CreationEntity> {

	@Override
	public CreationEntity deserialize(JsonParser jsonParser, DeserializationContext ctxt)
			throws IOException, JsonProcessingException {
		ObjectNode node = jsonParser.getCodec().readTree(jsonParser);
		Iterator<Map.Entry<String, JsonNode>> fields = node.fields();
		Map<String, Object> entityFields = new HashMap<String, Object>();
		while (fields.hasNext()) {
			Map.Entry<String, JsonNode> entry = fields.next();
			String key = entry.getKey();
			JsonNode val = entry.getValue();
			if (val instanceof TextNode) {
				entityFields.put(key, val.asText());
			} else if (val instanceof ArrayNode) {
				List<String> refs = new ArrayList<>();
				((ArrayNode) val).iterator().forEachRemaining(n -> {
				 	if (n instanceof TextNode) {
				 		refs.add(n.asText());		 		
				 	} else {
				 		raiseFormatException();
				 	}
				 		
				});
				entityFields.put(key, refs.toArray(new String[0]));
			} else {
				raiseFormatException();
			}
				
		}
		return new CreationEntity(entityFields);
	}

	private void raiseFormatException() {
		throw new RuntimeException("The JSON document does not conform to the valid format");
	}

}
