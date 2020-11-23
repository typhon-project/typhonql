package nl.cwi.swat.typhonql.backend.nlp;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;

import com.fasterxml.jackson.databind.JsonNode;

import nl.cwi.swat.typhonql.backend.ResultIterator;
import nl.cwi.swat.typhonql.backend.rascal.Path;

public class NlpIterator implements ResultIterator {
	
	private static final String MALFORMED_PAYLOAD_MESSAGE = "Wrong response from NLAE engine";
	
	private static enum TYPE {
		INTEGER, BOOLEAN, STRING
	}
	
	private static final Map<String, TYPE> TYPES = new HashMap<String, NlpIterator.TYPE>();
	
	static {
		TYPES.put("SentimentAnalysis$Sentiment", TYPE.INTEGER);
		TYPES.put("SentimentAnalysis$begin", TYPE.INTEGER);
		TYPES.put("SentimentAnalysis$end", TYPE.INTEGER);
		TYPES.put("NamedEntityRecognition$NamedEntity", TYPE.STRING);
	}
	
	private int index = -1;
	private final JsonNode records;
	private final Map<String, Integer> columnHeaders;
	
	public NlpIterator(JsonNode resultsNode) {
		JsonNode header = resultsNode.get("header");
		records = resultsNode.get("records");
		
		if (header == null || !header.isArray() || records == null || !records.isArray()) 
			throw new RuntimeException(MALFORMED_PAYLOAD_MESSAGE);	
			
		columnHeaders = new HashMap<String, Integer>();
		for (int i = 0; i < header.size(); i++) {
			columnHeaders.put(header.get(i).asText(), i);
		}
		
		beforeFirst();
	}

	@Override
	public void nextResult() {
		index++;
	}

	@Override
	public boolean hasNextResult() {
		return (index < records.size() - 1);
	}
	
	JsonNode getCurrentResult() {
		return records.get(index);
	}

	@Override
	public UUID getCurrentId(String label, String type) {
		String simpleLabel = label.split("__")[2];
		Integer i = columnHeaders.get(simpleLabel + ".@id");
		if (i == null) {
			return null;
		}
        return UUID.fromString(getCurrentResult().get(i).asText());
	}

	@Override
	public Object getCurrentField(String label, String ty, String name) {
		String[] parts = name.split("\\$");
		// part 0 is original attribute name, e.g., mission
		// part 1 is analysis
		// part 2 is attribute of analysis
		TYPE type = TYPES.get(parts[1]+"$"+parts[2]);
		String simpleLabel = label.split("__")[2];
		String actualPath = name.replace("$", ".");
		Integer i = columnHeaders.get(simpleLabel+"."+actualPath);
		if (i == null) {
			return null;
		}
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
		index = -1;
	}

}
