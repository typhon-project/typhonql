package nl.cwi.swat.typhonql.backend;

public class Field implements Binding {
	private String reference;
	private String label;
	private String type;
	private String attribute;
	
	public Field(String reference, String label, String type) {
		super();
		this.type = type;
		this.label = label;
		this.reference = reference;
		this.attribute = "@id";
	}
	
	public Field(String reference, String label, String type, String attribute) {
		super();
		this.type = type;
		this.label = label;
		this.reference = reference;
		this.attribute = attribute;
	}
	
	public String getLabel() {
		return label;
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