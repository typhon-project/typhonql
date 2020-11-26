package nl.cwi.swat.typhonql.backend.neo4j;

import java.util.Iterator;
import java.util.List;
import java.util.UUID;

import org.codehaus.groovy.syntax.Types;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.LinearRing;
import org.locationtech.jts.geom.PrecisionModel;
import org.neo4j.driver.Record;
import org.neo4j.driver.Value;
import org.neo4j.driver.Values;
import org.neo4j.driver.internal.types.InternalTypeSystem;
import org.neo4j.driver.types.Point;
import org.neo4j.driver.types.TypeSystem;

import nl.cwi.swat.typhonql.backend.ResultIterator;

public class Neo4JIterator implements ResultIterator {

	private List<Record> records;
	private Iterator<Record> iterator;
	private Record current;
	private static TypeSystem TYPES = InternalTypeSystem.TYPE_SYSTEM;
	
	private static final GeometryFactory wsgFactory = new GeometryFactory(new PrecisionModel(), 4326);
	
	public Neo4JIterator(List<Record> records) {
		this.records = records;
		this.iterator = records.iterator();
	}

	@Override
	public void nextResult() {
		this.current = iterator.next();
	}

	@Override
	public boolean hasNextResult() {
		// TODO Auto-generated method stub
		return iterator.hasNext();
	}

	@Override
	public UUID getCurrentId(String label, String type) {
		return UUID.fromString(current.get(label + "." + type + ".@id", ""));
	}
	
	@Override
	public Object getCurrentField(String label, String type, String name) {
		Value v = current.get(label + "." + type + "." + name);
		return getFieldForType(v);
	}

	private Object getFieldForType(Value v) {
		if (v.hasType(TYPES.STRING())) {
			return v.asString();
		}
		else if (v.hasType(TYPES.INTEGER())) {
			return v.asLong();
		}
		else if (v.hasType(TYPES.BOOLEAN())) {
			return v.asBoolean();
		}
		else if (v.hasType(TYPES.FLOAT())) {
			return v.asDouble();
		}
		else if (v.hasType(TYPES.DATE())) {
			return v.asLocalDate();
		}
		else if (v.hasType(TYPES.DATE_TIME())) {
			return v.asOffsetDateTime().toInstant();
		}
		else if (v.hasType(TYPES.LIST())) {
			List<List<Object>> lines = v.asList(Values.ofList());
			if (lines.size() > 0) {
                try {
                    LinearRing shell = createRing(lines.get(0));
                    LinearRing[] holes = new LinearRing[lines.size() - 1];
                    for (int i = 0; i < holes.length; i++) {
                        holes[i] = createRing(lines.get(i + 1));
                    }
                    return wsgFactory.createPolygon(shell, holes);
                }
                catch (Exception e) {
                    throw new RuntimeException("Failure to translate Polygon to Geometry: " + v, e);
                }
            }
		}
		if (v.hasType(TYPES.POINT())) {
			Point p = v.asPoint();
			return wsgFactory.createPoint(new Coordinate(p.x(), p.y()));
		}
		if (v.hasType(TYPES.NULL())) {
			return null;
		}
		else
			throw new RuntimeException("There is no mapper for Neo4J type " + v.type().name());
	}
	
	private static LinearRing createRing(List<Object> coords) {
		
		Coordinate[] points = new Coordinate[coords.size()];
		for (int i = 0; i < points.length; i++) {
			// Downcast is ok because this is the only possible occurrence of a list in neo4j
			List<Double> coord = (List<Double>) coords.get(i);
			points[i] = createCoordinate(coord);
		}
		return wsgFactory.createLinearRing(points);
	}
	

	private static Coordinate createCoordinate(List<Double> coords) {
		
		return new Coordinate(coords.get(0), coords.get(1));
	}

	@Override
	public void beforeFirst() {
		iterator = records.iterator();

	}

}
