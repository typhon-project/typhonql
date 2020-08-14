package nl.cwi.swat.typhonql.backend;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class MultipleBindings {
	
	private List<String> varNames;
	private List<String> varTypes;
	private Map<String, String> typesMap;
	private List<List<String>> values;
	
	public MultipleBindings(List<String> varNames, List<String> varTypes, List<List<String>> values) {
		super();
		this.varNames = varNames;
		this.varTypes = varTypes;
		this.values = values;
		this.typesMap = new HashMap<String, String>();
		for (int i = 0; i < varNames.size(); i++) {
			typesMap.put(varNames.get(i), varTypes.get(i));
		}
	}


	public List<String> getVarNames() {
		return varNames;
	}

	public List<String> getVarTypes() {
		return varTypes;
	}

	public List<List<String>> getValues() {
		return values;
	}

	public Map<String, String> getTypesMap() {
		return typesMap;
	}
	

}
