package nl.cwi.swat.typhonql.workingset;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import com.fasterxml.jackson.databind.util.StdConverter;

public class EntityRefConverter extends StdConverter<Object, Object> {

	@Override
	public Object convert(Object value) {
		if (value instanceof Map) {
			return new EntityRef((String) ((Map<String, Object>) value).get("uuid"));
		}
		if (value instanceof List) {
			return ((List) value).stream().map(this::convert).collect(Collectors.toList());
		}
		return value;
	}
	
}
