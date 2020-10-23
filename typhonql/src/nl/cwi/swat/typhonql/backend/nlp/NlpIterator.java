package nl.cwi.swat.typhonql.backend.nlp;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import com.fasterxml.jackson.databind.JsonNode;

import nl.cwi.swat.typhonql.backend.ResultIterator;

public class NlpIterator implements ResultIterator {
	
	private static final String MALFORMED_PAYLOAD_MESSAGE = "Wrong response from NLAE engine";
	
	private static enum TYPE {
		INTEGER, BOOLEAN, STRING
	}
	
	private static final Map<String, TYPE> TYPES = new HashMap<String, NlpIterator.TYPE>();
	
	static {
		TYPES.put("SentimentAnalysis$Sentiment", TYPE.INTEGER);
	}
	
	private int index = -1;
	private JsonNode records;
	Map<String, Integer> columnHeaders;

	public NlpIterator(JsonNode resultsNode) {
		JsonNode header = resultsNode.get("header");
		JsonNode records = resultsNode.get("records");
		
		if (header == null || !header.isArray() || records == null || !records.isArray()) 
			throwWrongFormatException();
			
		columnHeaders = new HashMap<String, Integer>();
		for (int i = 0; i < header.size(); i++) {
			columnHeaders.put(header.get(i).asText(), i);
		}
		
		beforeFirst();
	}

	private void throwWrongFormatException() {
		throw new RuntimeException(MALFORMED_PAYLOAD_MESSAGE);	
	}

	@Override
	public void nextResult() {
		index++;
	}

	@Override
	public boolean hasNextResult() {
		return (index < records.size());
	}
	
	JsonNode getCurrentResult() {
		return records.get(index);
	}

	@Override
	public UUID getCurrentId(String label, String type) {
		int i = columnHeaders.get(label + ".@id");
		String str = getCurrentResult().get(i).asText();
		return UUID.fromString(str);
	}

	@Override
	public Object getCurrentField(String label, String ty, String name) {
		String[] parts = name.split("$");
		// part 0 is original attribute name, e.g., mission
		// part 1 is analysis
		// part 2 is attribute of analysis
		TYPE type = TYPES.get(parts[1]+"$"+parts[2]);
		int i = columnHeaders.get(label + ".@id");
		JsonNode node = getCurrentResult().get(i);
		switch (type) {
		case INTEGER:
			return node.asInt();
		case STRING:
			return node.asText();
		case BOOLEAN:
			// TODO can we actually get booleans?
			return node.asBoolean();
		}
		throw new RuntimeException(MALFORMED_PAYLOAD_MESSAGE);	
	}

	@Override
	public void beforeFirst() {
		index = 0;
	}

}
