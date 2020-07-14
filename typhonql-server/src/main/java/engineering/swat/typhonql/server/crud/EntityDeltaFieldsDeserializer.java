/********************************************************************************
* Copyright (c) 2018-2020 CWI & Swat.engineering 
*
* This program and the accompanying materials are made available under the
* terms of the Eclipse Public License 2.0 which is available at
* http://www.eclipse.org/legal/epl-2.0.
*
* This Source Code may also be made available under the following Secondary
* Licenses when the conditions for such availability set forth in the Eclipse
* Public License, v. 2.0 are satisfied: GNU General Public License, version 2
* with the GNU Classpath Exception which is
* available at https://www.gnu.org/software/classpath/license.html.
*
* SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0
********************************************************************************/

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

public class EntityDeltaFieldsDeserializer extends JsonDeserializer<EntityDeltaFields> {

	@Override
	public EntityDeltaFields deserialize(JsonParser jsonParser, DeserializationContext ctxt)
			throws IOException, JsonProcessingException {
		ObjectNode node = jsonParser.getCodec().readTree(jsonParser);
		Iterator<Map.Entry<String, JsonNode>> fields = node.fields();
		Map<String, String> simpleFields = new HashMap<String, String>();
		Map<String, List<String>> set = new HashMap<String, List<String>>();
		Map<String, List<String>> add = new HashMap<String, List<String>>();
		Map<String, List<String>> remove = new HashMap<String, List<String>>();
		while (fields.hasNext()) {
			Map.Entry<String, JsonNode> entry = fields.next();
			String key = entry.getKey();
			JsonNode val = entry.getValue();
			if (val instanceof TextNode) {
				simpleFields.put(key, val.asText());
			} else if (val instanceof ObjectNode) {
				ObjectNode obj = (ObjectNode) val;
				if (obj.has("set" )) {
					JsonNode arrayNode = obj.get("set");
					if (arrayNode instanceof ArrayNode) {
						set.put(key, getList((ArrayNode) arrayNode));
					}
					else
						raiseFormatException();
				}
				if (obj.has("add" )) {
					JsonNode arrayNode = obj.get("add");
					if (arrayNode instanceof ArrayNode) {
						add.put(key, getList((ArrayNode) arrayNode));
					}
					else
						raiseFormatException();
				}
				if (obj.has("remove" )) {
					JsonNode arrayNode = obj.get("remove");
					if (arrayNode instanceof ArrayNode) {
						remove.put(key, getList((ArrayNode) arrayNode));
					}
					else
						raiseFormatException();
				}
			} else {
				raiseFormatException();
			}
				
		}
		return new EntityDeltaFields(simpleFields, set, add, remove);
	}

	private List<String> getList(ArrayNode array) {
		List<String> refs = new ArrayList<>();
		array.iterator().forEachRemaining(n -> {
		 	if (n instanceof TextNode) {
		 		refs.add(n.asText());		 		
		 	} else {
		 		raiseFormatException();
		 	}
		 		
		});
		return refs;
	}

	private void raiseFormatException() {
		throw new RuntimeException("The JSON document does not conform to the valid format");
	}

}
