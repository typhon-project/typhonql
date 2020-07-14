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

public class EntityFieldsDeserializer extends JsonDeserializer<EntityFields> {

	@Override
	public EntityFields deserialize(JsonParser jsonParser, DeserializationContext ctxt)
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
		return new EntityFields(entityFields);
	}

	private void raiseFormatException() {
		throw new RuntimeException("The JSON document does not conform to the valid format");
	}

}
