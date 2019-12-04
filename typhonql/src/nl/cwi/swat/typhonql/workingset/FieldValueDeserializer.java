package nl.cwi.swat.typhonql.workingset;

import java.io.IOException;

import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.DeserializationContext;
import com.fasterxml.jackson.databind.JsonDeserializer;

public class FieldValueDeserializer extends JsonDeserializer<Object> {

	/*
	@Override
	public Object deserialize(JsonParser jp, DeserializationContext ctxt) throws IOException, JsonProcessingException {
		JsonNode node = jp.getCodec().readTree(jp);
		if (node.has("uuid")) {
			String uuid = ((TextNode) node.get("uuid")).textValue();
			return new EntityRef(uuid);
		}
        return new ObjectMapper().readValue(node.asText(), Object.class);
	}*/
	
	@Override
	public Object deserialize(JsonParser jp, DeserializationContext ctxt) throws IOException, JsonProcessingException {
		try {
			return jp.readValueAs(EntityRef.class);
		}
		catch (com.fasterxml.jackson.databind.exc.MismatchedInputException e) {
			return jp.readValueAs(Object.class);
		}

	}
	
}
