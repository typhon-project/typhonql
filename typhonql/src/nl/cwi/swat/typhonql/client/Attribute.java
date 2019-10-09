package nl.cwi.swat.typhonql.client;

public class Attribute {

	//alias Attrs = rel[str from, str name, str \type];
	
	private String from;
	private String name;
	private String type;
	
	public Attribute(String from, String name, String type) {
		super();
		this.from = from;
		this.name = name;
		this.type = type;
	}

	public String getFrom() {
		return from;
	}

	public String getName() {
		return name;
	}

	public String getType() {
		return type;
	}
	
	
	
}
