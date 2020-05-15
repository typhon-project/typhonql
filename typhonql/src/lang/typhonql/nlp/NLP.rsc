module lang::typhonql::nlp::NLP

import String;

alias NLPProcessRequest = tuple[str entityType, str fieldName, str id, list[str] features, str text];

data NLPTask = 
	nlpIngestion(list[NLPProcessRequest] requests);
	
list[str] freetextType2features(str ty) {
	str polished = replaceFirst(replaceLast(ty, "]", ""), "freetext[", "");
	list[str] features = split(", ", polished);
	return features;
}