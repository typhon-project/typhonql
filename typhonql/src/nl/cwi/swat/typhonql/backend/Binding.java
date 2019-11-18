package nl.cwi.swat.typhonql.backend;

import java.util.Optional;

public class Binding {
	private String id;
	private String reference;
	private Optional<String> attribute;
	
	public Binding(String id, String reference) {
		super();
		this.id = id;
		this.reference = reference;
		this.attribute = Optional.empty();
	}
	
	public Binding(String id, String reference, String attribute) {
		super();
		this.id = id;
		this.reference = reference;
		this.attribute = Optional.of(attribute);
	}
	public String getId() {
		return id;
	}
	
	public String getReference() {
		return reference;
	}
	
	public Optional<String> getAttribute() {
		return attribute;
	}
}
