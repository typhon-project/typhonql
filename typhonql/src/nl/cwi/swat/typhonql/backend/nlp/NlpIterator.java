package nl.cwi.swat.typhonql.backend.nlp;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;

import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.PrecisionModel;
import org.locationtech.jts.io.ParseException;
import org.locationtech.jts.io.WKTReader;

import com.fasterxml.jackson.databind.JsonNode;

import nl.cwi.swat.typhonql.backend.ResultIterator;

public class NlpIterator implements ResultIterator {
	
	private static final String MALFORMED_PAYLOAD_MESSAGE = "Wrong response from NLAE engine";
	

	private static final GeometryFactory wsgFactory = new GeometryFactory(new PrecisionModel(), 4326);
	private static Geometry readWKT(String s) {
		try {
			Geometry result = new WKTReader(wsgFactory).read(s);
			if (result == null) {
				throw new RuntimeException("Error parsing geometry: " + s);
			}
			return result;
		} catch (ParseException e) {
			throw new RuntimeException("Error parsing geometry", e);
		}
	}
	
	private static final Map<String, Function<JsonNode, Object>> ResultMapper = new HashMap<>();
	
	static {
		// generated by lang typhonml::Util::generateLookupTable!
		ResultMapper.put("PhraseExtraction$Token", JsonNode::asText);
		ResultMapper.put("PhraseExtraction$end", JsonNode::asLong);
		ResultMapper.put("PhraseExtraction$begin", JsonNode::asLong);
		ResultMapper.put("POSTagging$end", JsonNode::asLong);
		ResultMapper.put("POSTagging$begin", JsonNode::asLong);
		ResultMapper.put("POSTagging$PosTag", JsonNode::asText);
		ResultMapper.put("POSTagging$PosValue", JsonNode::asText);
		ResultMapper.put("RelationExtraction.TargetEntity$NamedEntity", JsonNode::asText);
		ResultMapper.put("RelationExtraction$RelationName", JsonNode::asText);
		ResultMapper.put("RelationExtraction.TargetEntity$begin", JsonNode::asLong);
		ResultMapper.put("RelationExtraction.TargetEntity$end", JsonNode::asLong);
		ResultMapper.put("RelationExtraction$end", JsonNode::asLong);
		ResultMapper.put("RelationExtraction$begin", JsonNode::asLong);
		ResultMapper.put("RelationExtraction.SourceEntity$NamedEntity", JsonNode::asText);
		ResultMapper.put("RelationExtraction.SourceEntity$end", JsonNode::asLong);
		ResultMapper.put("RelationExtraction.SourceEntity$begin", JsonNode::asLong);
		ResultMapper.put("nGramExtraction$NgramType", JsonNode::asText);
		ResultMapper.put("nGramExtraction$begin", JsonNode::asLong);
		ResultMapper.put("nGramExtraction$end", JsonNode::asLong);
		ResultMapper.put("ParagraphSegmentation$end", JsonNode::asLong);
		ResultMapper.put("ParagraphSegmentation$begin", JsonNode::asLong);
		ResultMapper.put("ParagraphSegmentation$Paragraph", JsonNode::asText);
		ResultMapper.put("Tokenisation$Token", JsonNode::asText);
		ResultMapper.put("Tokenisation$end", JsonNode::asLong);
		ResultMapper.put("Tokenisation$begin", JsonNode::asLong);
		ResultMapper.put("TermExtraction$end", JsonNode::asLong);
		ResultMapper.put("TermExtraction$WeightedToken", JsonNode::asLong);
		ResultMapper.put("TermExtraction.TargetEntity$NamedEntity", JsonNode::asLong);
		ResultMapper.put("TermExtraction$begin", JsonNode::asLong);
		ResultMapper.put("TermExtraction.TargetEntity$begin", JsonNode::asLong);
		ResultMapper.put("TermExtraction.TargetEntity$end", JsonNode::asLong);
		ResultMapper.put("Chunking$begin", JsonNode::asLong);
		ResultMapper.put("Chunking$end", JsonNode::asLong);
		ResultMapper.put("Chunking.PosAnnotation$PosValue", JsonNode::asText);
		ResultMapper.put("Chunking.PosAnnotation$end", JsonNode::asLong);
		ResultMapper.put("Chunking.TokenAnnotation$begin", JsonNode::asLong);
		ResultMapper.put("Chunking.TokenAnnotation$end", JsonNode::asLong);
		ResultMapper.put("Chunking.PosAnnotation$PosTag", JsonNode::asText);
		ResultMapper.put("Chunking.PosAnnotation$begin", JsonNode::asLong);
		ResultMapper.put("Chunking.TokenAnnotation$Token", JsonNode::asText);
		ResultMapper.put("Chunking$Label", JsonNode::asText);
		ResultMapper.put("NamedEntityRecognition$NamedEntity", JsonNode::asText);
		ResultMapper.put("NamedEntityRecognition$begin", JsonNode::asLong);
		ResultMapper.put("NamedEntityRecognition$GeoCode", n -> readWKT(n.asText()));
		ResultMapper.put("NamedEntityRecognition$WordToken", JsonNode::asText);
		ResultMapper.put("NamedEntityRecognition$end", JsonNode::asLong);
		ResultMapper.put("Stemming$begin", JsonNode::asLong);
		ResultMapper.put("Stemming$end", JsonNode::asLong);
		ResultMapper.put("Stemming$Stem", JsonNode::asText);
		ResultMapper.put("Lemmatisation$begin", JsonNode::asLong);
		ResultMapper.put("Lemmatisation$end", JsonNode::asLong);
		ResultMapper.put("Lemmatisation$Lemma", JsonNode::asText);
		ResultMapper.put("DependencyParsing$DependencyName", JsonNode::asText);
		ResultMapper.put("DependencyParsing.TargetEntity$NamedEntity", JsonNode::asText);
		ResultMapper.put("DependencyParsing.TargetEntity$begin", JsonNode::asLong);
		ResultMapper.put("DependencyParsing.TargetEntity$end", JsonNode::asLong);
		ResultMapper.put("DependencyParsing$begin", JsonNode::asLong);
		ResultMapper.put("DependencyParsing.SourceEntity$begin", JsonNode::asLong);
		ResultMapper.put("DependencyParsing.SourceEntity$end", JsonNode::asLong);
		ResultMapper.put("DependencyParsing$end", JsonNode::asLong);
		ResultMapper.put("DependencyParsing.SourceEntity$NamedEntity", JsonNode::asText);
		ResultMapper.put("SentenceSegmentation$Sentence", JsonNode::asText);
		ResultMapper.put("SentenceSegmentation$begin", JsonNode::asLong);
		ResultMapper.put("SentenceSegmentation$end", JsonNode::asLong);
		ResultMapper.put("SentimentAnalysis$SentimentLabel", JsonNode::asText);
		ResultMapper.put("SentimentAnalysis$Sentiment", JsonNode::asLong);
		ResultMapper.put("RelationExtraction.Anaphor$begin", JsonNode::asLong);
		ResultMapper.put("RelationExtraction.Anaphor$Token", JsonNode::asText);
		ResultMapper.put("RelationExtraction.Anaphor$end", JsonNode::asLong);
		ResultMapper.put("CoreferenceResolution.Antecedent$end", JsonNode::asLong);
		ResultMapper.put("CoreferenceResolution$begin", JsonNode::asLong);
		ResultMapper.put("CoreferenceResolution.Antecedent$begin", JsonNode::asLong);
		ResultMapper.put("CoreferenceResolution$end", JsonNode::asLong);
		ResultMapper.put("CoreferenceResolution.Antecedent$Token", JsonNode::asText);
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
		Function<JsonNode, Object> mapper = ResultMapper.get(parts[1]+"$"+parts[2]);
		if (mapper == null) {
			throw new RuntimeException(MALFORMED_PAYLOAD_MESSAGE);	
		}
		String simpleLabel = label.split("__")[2];
		String actualPath = name.replace('$', '.');
		Integer i = columnHeaders.get(simpleLabel+"."+actualPath);
		if (i == null) {
			return null;
		}
		return mapper.apply(getCurrentResult().get(i));
	}

	@Override
	public void beforeFirst() {
		index = -1;
	}

}
