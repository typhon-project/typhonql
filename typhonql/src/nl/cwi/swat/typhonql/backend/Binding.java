package nl.cwi.swat.typhonql.backend;

public class Binding {
	private String reference;
	private String type;
	private String attribute;
	
	public Binding(String reference, String type) {
		super();
		this.type = type;
		this.reference = reference;
		this.attribute = "@id";
	}
	
	public Binding(String reference, String type, String attribute) {
		super();
		this.type = type;
		this.reference = reference;
		this.attribute = attribute;
	}
	public String getType() {
		return type;
	}
	
	public String getReference() {
		return reference;
	}
	
	public String getAttribute() {
		return attribute;
	}
}
