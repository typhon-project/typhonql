package nl.cwi.swat.typhonql.backend;

import java.util.HashMap;
import java.util.Map;

public class ExternalArguments {
	private String[] varNames;
	private Object[][] values;
	
	public ExternalArguments() {
		this(new String[] {}, new Object[][] {});
	}
	
	public ExternalArguments(String[] varNames, Object[][] values) {
		super();
		this.varNames = varNames;
		this.values = values;
	}
	public String[] getVarNames() {
		return varNames;
	}

	public Object[][] getValues() {
		return values;
	}
	public Map<String, Object> getMapForRow(int index) {
		Object[] row = values[index];
		Map<String, Object> map = new HashMap<String, Object>();
		for (int i=0; i < varNames.length; i++) {
			map.put(varNames[i], row[i]);
		}
		return map;
	}
	
	
}
