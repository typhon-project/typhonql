package nl.cwi.swat.typhonql.client;

public class Relation {
	//alias Rel = tuple[str from, Cardinality fromCard, str fromRole, str toRole, Cardinality toCard, str to, bool containment];
	
	private String from;
	private Cardinality fromCard;
	private String fromRole;
	private String toRole;
	private Cardinality toCard;
	private String to;
	private boolean containment;
	
	public Relation(String from, Cardinality fromCard, String fromRole, String toRole, Cardinality toCard, String to,
			boolean containment) {
		super();
		this.from = from;
		this.fromCard = fromCard;
		this.fromRole = fromRole;
		this.toRole = toRole;
		this.toCard = toCard;
		this.to = to;
		this.containment = containment;
	}
	
	public String getFrom() {
		return from;
	}
	public Cardinality getFromCard() {
		return fromCard;
	}
	public String getFromRole() {
		return fromRole;
	}
	public String getToRole() {
		return toRole;
	}
	public Cardinality getToCard() {
		return toCard;
	}
	public String getTo() {
		return to;
	}
	public boolean isContainment() {
		return containment;
	}
	
	
}
