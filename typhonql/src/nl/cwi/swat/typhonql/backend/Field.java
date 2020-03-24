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
	
	@Override
	public int hashCode() {
		return type.hashCode() *3 + label.hashCode() * 7
				+ reference.hashCode() * 11 + attribute.hashCode() * 13;
	}
	
	@Override
	public boolean equals(Object obj) {
		if (obj != null) {
			if (obj instanceof Field) {
				Field f = (Field) obj;
				return type.equals(f.type) && label.equals(f.label)
						&& reference.equals(f.reference) && attribute.equals(f.attribute);
			}
			else
				return false;
		}
		return false;
	}
}
