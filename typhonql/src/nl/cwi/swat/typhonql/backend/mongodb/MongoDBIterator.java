/********************************************************************************
* Copyright (c) 2018-2020 CWI & Swat.engineering 
*
* This program and the accompanying materials are made available under the
* terms of the Eclipse Public License 2.0 which is available at
* http://www.eclipse.org/legal/epl-2.0.
*
* This Source Code may also be made available under the following Secondary
* Licenses when the conditions for such availability set forth in the Eclipse
* Public License, v. 2.0 are satisfied: GNU General Public License, version 2
* with the GNU Classpath Exception which is
* available at https://www.gnu.org/software/classpath/license.html.
*
* SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0
********************************************************************************/

package nl.cwi.swat.typhonql.backend.mongodb;

import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Date;
import java.util.List;
import java.util.UUID;

import org.bson.Document;
import org.bson.types.BSONTimestamp;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.LinearRing;
import org.locationtech.jts.geom.PrecisionModel;

import com.mongodb.MongoGridFSException;
import com.mongodb.client.MongoCursor;
import com.mongodb.client.MongoDatabase;
import com.mongodb.client.MongoIterable;
import com.mongodb.client.gridfs.GridFSBucket;
import com.mongodb.client.gridfs.GridFSBuckets;

import nl.cwi.swat.typhonql.backend.ResultIterator;

public class MongoDBIterator implements ResultIterator {
	private final MongoIterable<Document> results;
	private final MongoDatabase source;
	private GridFSBucket gridBucket = null;
	private MongoCursor<Document> cursor = null;
	private Document current = null;

	public MongoDBIterator(MongoIterable<Document> results, MongoDatabase source) {
		this.results = results;
		this.source = source;
		this.cursor = results.cursor();
	}
	
	public GridFSBucket getGridBucket() {
		if (gridBucket == null) {
			return gridBucket = GridFSBuckets.create(source);
		}
		return gridBucket;
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
	public UUID getCurrentId(String label, String type) {
		return current.get("_id", UUID.class);
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
			// due to strange way dates & timestamps are stored in mogo, we swap them around
			return ((Date)fromDB).toInstant();
		}
		else if (fromDB instanceof BSONTimestamp) {
			 long seconds = ((BSONTimestamp) fromDB).getTime();
			 int beforEpoch = ((BSONTimestamp) fromDB).getInc();
			 return Instant.ofEpochSecond(seconds * beforEpoch).atOffset(ZoneOffset.UTC).toLocalDate();
		}
		else if (fromDB instanceof String) {
			String strValue = (String)fromDB;
			if (strValue.startsWith("#blob:")) {
				String blobName = strValue.substring("#blob:".length());
				try {
					return getGridBucket().openDownloadStream(blobName);
				}
				catch (MongoGridFSException e) {
                    throw new RuntimeException("Referenced blob: " + blobName + " doesn't exist", e);
				}
			}
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
