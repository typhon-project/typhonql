package nl.cwi.swat.typhonql.client;

import java.util.Map;
import java.util.List;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.impl.persistent.ValueFactory;

public class PolystoreSchema {

	/*
	alias JavaFriendlySchema = tuple[rel[str from, str fromCard, str fromRole, str toRole, str toCard, str to, bool containment] rels, 
		rel[str from, str name, str \type] attrs, rel[str dbEngineType, str dbName, str entity] placement];
	
	*/
	
	private List<Relation> rels;
	private List<Attribute> attrs;
	private Map<Place, List<String>> placement; 
	
	public PolystoreSchema(List<Relation> rels, List<Attribute> attrs, Map<Place, List<String>> placement) {
		super();
		this.rels = rels;
		this.attrs = attrs;
		this.placement = placement;
	}



	public IValue asRascalValue() {
		IValueFactory vf =ValueFactory.getInstance();
		IValue rrels = vf.set(
				rels.stream().map(r -> vf.tuple(vf.string(r.getFrom()), vf.string(r.getFromCard().toString()), 
						vf.string(r.getFromRole()), vf.string(r.getToRole()), vf.string(r.getToCard().toString()), vf.string(r.getTo()), 
						vf.bool(r.isContainment()))).collect(Collectors.toList()).toArray(new IValue[0]));
		IValue rattrs = vf.set(
				attrs.stream().map(a -> vf.tuple(vf.string(a.getFrom()), vf.string(a.getName().toString()), 
						vf.string(a.getType()))).collect(Collectors.toList()).toArray(new IValue[0]));
		IValue rplacement = vf.set(
				placement.keySet().stream().flatMap(p -> toPlacementTuple(vf, p)).collect(Collectors.toList()).toArray(new IValue[0]));
		IValue r = vf.tuple(rrels, rattrs, rplacement);
		return r;
	}



	private Stream<IValue> toPlacementTuple(IValueFactory vf, Place p) {
		return placement.get(p).stream().map(entity -> vf.tuple(vf.string(p.getDBType().name()), vf.string(p.getName()), vf.string(entity)));
	}

}
