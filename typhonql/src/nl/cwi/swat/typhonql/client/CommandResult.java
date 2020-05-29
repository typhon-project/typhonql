package nl.cwi.swat.typhonql.client;

import java.io.IOException;
import java.io.OutputStream;
import java.util.Collections;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.Map.Entry;

import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.databind.ObjectMapper;

import io.usethesource.vallang.IInteger;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;
import nl.cwi.swat.typhonql.client.resulttable.JsonSerializableResult;

public class CommandResult implements JsonSerializableResult {
	private static final ObjectMapper mapper = new ObjectMapper()
			.configure(JsonGenerator.Feature.AUTO_CLOSE_TARGET, false);
	
	private final int affectedEntities;
	private final Map<String, String> createdUuids;
	
	public CommandResult(int affectedEntities, Map<String, String> createdUuids) {
		this.affectedEntities = affectedEntities;
		this.createdUuids = createdUuids;
	}
	
	public CommandResult(int affectedEntities) {
		this(affectedEntities, Collections.emptyMap());
	}

	public int getAffectedEntities() {
		return affectedEntities;
	}

	public Map<String, String> getCreatedUuids() {
		return createdUuids;
	}

	@Override
	public void serializeJSON(OutputStream target) throws IOException {
		mapper.writeValue(target, this);
	}
	
	public static CommandResult fromIValue(IValue val) {
		ITuple tuple = (ITuple) val;
		IInteger n = (IInteger) tuple.get(0);
		IMap smap = (IMap) tuple.get(1);
		Map<String, String> map = new HashMap<String, String>();
		Iterator<Entry<IValue, IValue>> iter = smap.entryIterator();
		while (iter.hasNext()) {
			Entry<IValue, IValue> entry = iter.next();
			map.put(((IString) entry.getKey()).getValue(), ((IString) entry.getValue()).getValue());
		}
		return new CommandResult(((IInteger) n).intValue(), map);
	}

}
