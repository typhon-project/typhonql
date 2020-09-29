module lang::typhonql::nlp::Nlp

import List;

data NlpId = id(str id) | placeholder(str name);

/*
  id": "12345",
  "entityType": "review",
  "fieldName": "comment",
  "text": "text to be processed",
  "nlpFeatures": [
    "sentimentanalysis"
  ],
  "workflowNames": [
    "workflow1"
  ]

*/
str getProcessJson(NlpId id, str entity, str field, str text, rel[str,str] analyses) {
	return 
		"{
		|	\"id\": <pp(id)>
		|	\"entityType\": <entity>
		|	\"fieldName\": <field>
		|	\"text\": <text>
		|	\"nlpFeatures\": [<intercalate(", ", ["\"<a>\"" | <a, w> <- analyses])>]
		|	\"workflowNames\": [<intercalate(", ", ["\"<w>\"" | <a, w> <- analyses])>]
		|}";

}

str getDeleteJson(NlpId id, str entity) {
	return 
		"{
		|	\"id\": <pp(id)>
		|	\"entityType\": <entity>
		|}";

}

str pp(id(str name)) = name;
str pp(placeholder(str name)) = "$<name>";