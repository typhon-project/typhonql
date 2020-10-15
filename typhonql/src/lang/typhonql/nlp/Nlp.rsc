module lang::typhonql::nlp::Nlp

import List;
import String;

data NlpId = id(str id) | placeholder(str name);

data NStat = nSelect(
	NFrom from,
	list[NWith] withs,
	list[NPath] selectors,
	list[NExpr] wheres);
	
data NFrom = nFrom(str entity, str label);
	
data NPath = nPath(str var, list[str] field);

data NWith = nWith(NPath path, str workflow);
	
data NExpr
	= nBinaryOp(str op, NExpr lhs, NExpr rhs)
	| nLiteral(str val, str \type)
	| nAttr(str var, list[str] path)
	| nPlaceholder(str name)
	;
	
str pp(nSelect(nFrom(str entity, str label), withs, selectors, wheres))
	= "{
	  '  \"from\": { \"entity\" : \"<ppEntity(entity)>\", \"named\" : \"<ppVar(label)>\"},
	  '	 \"with\": [<ppWiths>],
	  '  \"select\": [<ppSelectors>],
	  '  \"where\": [<ppWheres>]
	  '}"
	when ppWiths := intercalate(",", [pp(w) | w <- withs]),
	     ppSelectors := intercalate(",", [pp(p) | p <- selectors]),
	     ppWheres := intercalate(",", [pp(w) | w <- wheres]);

	
str pp(nWith(NPath path, str workflow)) = "{ \"path\": <pp(path)>, \"workflow\": \"<workflow>\"}";

str pp(nPath(str var, list[str] field)) = "\"<intercalate(".", [ppVar(var)] + field)>\"";

str pp(nBinaryOp(str op, NExpr lhs, NExpr rhs)) = "{\"op\": \"<op>\", \"lhs\": <pp(lhs)>, \"rhs\": <pp(rhs)> }";

str pp(nAttr(str var, list[str] path)) = "{\"attr\": \"<intercalate(".", [ppVar(var)] + path)>\"}";

str pp(nPlaceholder(str name)) = "${<name>}";

str pp(nLiteral(str val, str ty)) = "{\"lit\" : \"<val>\", \"type\" : \"<ty>\"}";
default str pp(nLiteral(str val, str ty)) = val;

str ppVar(str var) {
 	parts =split("__", var);
 	return parts[2];
}

str ppEntity(str ent) {
 	parts =split("___", ent);
 	return parts[0];
}

/*{
  “from”: {“entity”: “Review”, “named”: “r”}
  “with”: [{“path”: “r.text.SentimentAnalysis”, “workflow”: “wflow1”},
              {“path”:  “r.text.NamedEntityRecognition”, “workflow”: “wflow2”}],
  “select”: [“r.@id”, “r.text.SentimentAnalysis.sentiment”] 
  “where”: [
    {“op”: “>”, 
        “lhs”: {“attr”: “r.text.SentimentAnalysis.sentiment”},
        “rhs”: {“lit”: “5”, “type”: “int”}
    },
    {“op”: “in”,
       “lhs”: {“lit”: “Tesla”, “type”: “string”}
       “rhs”: {“attr”: “r.text.NamedEntityRecognition.entities”}
    }
  ]
}*/


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
		'	\"id\": \"<pp(id)>\",
		'	\"entityType\": \"<entity>\",
		'	\"fieldName\": \"<field>\",
		'	\"text\": \"<text>\",
		'	\"nlpFeatures\": [<intercalate(", ", ["\"<a>\"" | <a, w> <- analyses])>],
		'	\"workflowNames\": [<intercalate(", ", ["\"<w>\"" | <a, w> <- analyses])>]
		'}";

}

str getDeleteJson(NlpId id, str entity) {
	return 
		"{
		'	\"id\": \"<pp(id)>\",
		'	\"entityType\": \"<entity>\"
		'}";

}

str pp(id(str name)) = name;
str pp(placeholder(str name)) = "${<name>}";