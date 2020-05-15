package nl.cwi.swat.typhonql.backend;

import java.time.ZoneId;
import java.util.Date;
import java.util.List;
import org.bson.Document;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.LineString;
import org.locationtech.jts.geom.LinearRing;
import org.locationtech.jts.geom.PrecisionModel;
import com.mongodb.client.MongoCursor;
import com.mongodb.client.MongoIterable;

public class MongoDBIterator implements ResultIterator {
	private MongoIterable<Document> results;
	private MongoCursor<Document> cursor = null;
	private Document current = null;

	public MongoDBIterator(MongoIterable<Document> results) {
		this.results = results;
		this.cursor = results.cursor();
	}

	@Override
	public void nextResult() {
		this.current = cursor.next();
	}

	@Override
	public boolean hasNextResult() {
		return cursor.hasNext();
	}

	@Override
	public String getCurrentId(String label, String type) {
		return current.getString("_id");
	}

	@Override
	public Object getCurrentField(String label, String type, String name) {
		Object fromDB = current.get(name);
		return toTypedObject(fromDB, type);
	}

	private static final GeometryFactory wsgFactory = new GeometryFactory(new PrecisionModel(), 4326);

	@SuppressWarnings("unchecked")
	private Object toTypedObject(Object fromDB, String type) {
		if (fromDB instanceof Document) {
			// might be a geo field?
			Document geo = (Document) fromDB;
			switch (geo.get("type", "")) {
				case "Point": {
					List<Double> coords = geo.getList("coordinates", Double.class);
					if (coords.size() == 2) {
						return wsgFactory.createPoint(createCoordinate(coords));
					}
					break;
				}
				case "Polygon": {
					List<List> lines = geo.getList("coordinates", List.class);
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
							throw new RuntimeException("Failure to translate Polygon to Geometry: " + geo, e);
						}
					}
				}
			}
			throw new RuntimeException("Unsupported document in result. Doc:" + geo);
		}
		else if (fromDB instanceof Date) {
			return ((Date)fromDB).toInstant().atZone(ZoneId.of("UTC")).toLocalDateTime();
		}
		return fromDB;
	}

	private static LinearRing createRing(List<List<Double>> coords) {
		Coordinate[] points = new Coordinate[coords.size()];
		for (int i = 0; i < points.length; i++) {
			points[i] = createCoordinate(coords.get(i));
		}
		return wsgFactory.createLinearRing(points);
	}
	

	private static Coordinate createCoordinate(List<Double> coords) {
		return new Coordinate(coords.get(0), coords.get(1));
	}

	@Override
	public void beforeFirst() {
		cursor = results.cursor();
	}

}
