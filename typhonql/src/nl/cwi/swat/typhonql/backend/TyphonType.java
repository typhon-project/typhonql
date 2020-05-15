package nl.cwi.swat.typhonql.backend;

public enum TyphonType {
	INTEGER, STRING, BOOL, FLOAT, 
	BLOB, DATE, DATETIME, POINT, POLYGON,
	UUID;
	
	
	public static TyphonType lookup(String type) {
		type = type.toLowerCase();
		switch (type) {
			// sync with lang::typhonml::Util::model2attrs
			case "int":
			case "bigint": return INTEGER;
			case "blob": return BLOB;
			case "bool": return BOOL;
			case "date": return DATE;
			case "point": return POINT;
			case "polygon": return POLYGON;
			case "float": return FLOAT;
			default:
				if (type.equals("text") ||
						type.startsWith("string") || 
						type.startsWith("freetext")) {
					return STRING;
				}
				throw new RuntimeException("Unknown type: " + type);
		}
	}
	
}	
