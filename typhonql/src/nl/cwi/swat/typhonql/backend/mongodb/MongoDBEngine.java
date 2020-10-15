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

import java.io.IOException;
import java.io.InputStream;
import java.io.StringWriter;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.UUID;
import java.util.function.BiConsumer;
import java.util.function.Consumer;
import java.util.function.Supplier;
import java.util.regex.Matcher;
import java.util.stream.Collectors;

import org.apache.commons.text.StringSubstitutor;
import org.bson.Document;
import org.locationtech.jts.geom.Geometry;
import org.wololo.jts2geojson.GeoJSONWriter;

import com.fasterxml.jackson.core.JsonFactory;
import com.fasterxml.jackson.core.JsonGenerator;
import com.mongodb.MongoGridFSException;
import com.mongodb.MongoNamespace;
import com.mongodb.client.FindIterable;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;
import com.mongodb.client.gridfs.GridFSBucket;
import com.mongodb.client.gridfs.GridFSBuckets;
import com.mongodb.client.gridfs.GridFSDownloadStream;

import lang.typhonql.util.MakeUUID;
import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.Engine;
import nl.cwi.swat.typhonql.backend.QueryExecutor;
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultIterator;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.UpdateExecutor;
import nl.cwi.swat.typhonql.backend.rascal.Path;
import nl.cwi.swat.typhonql.backend.rascal.TyphonSessionState;

public class MongoDBEngine extends Engine {
	private final MongoDatabase db;
	private GridFSBucket gridBucket = null;
	
	private GridFSBucket getGridFS() {
		if (gridBucket == null) {
			return gridBucket = GridFSBuckets.create(db);
		}
		return gridBucket;
	}

	public MongoDBEngine(ResultStore store, TyphonSessionState state, List<Consumer<List<Record>>> script, Map<String, UUID> uuids, MongoDatabase db) {
		super(store, state, script, uuids);
		this.db = db;
	}

	public void executeFind(String resultId, String collectionName, String query, Map<String, Binding> bindings, List<Path> signature) {
		new QueryExecutor(store, script, uuids, bindings, signature, () -> "Mongo find: " + query) {
			@Override
			protected ResultIterator performSelect(Map<String, Object> values) {
				return new MongoDBIterator(buildFind(collectionName, query, values), db);
			}
		}.scheduleSelect(resultId);
	}

	public void executeFindWithProjection(String resultId, String collectionName, String query, String projection,
			Map<String, Binding> bindings, List<Path> signature) {
		new QueryExecutor(store, script, uuids, bindings, signature, () -> "Mongo projected find: " + query + " proj: " + projection) {
			@Override
			protected ResultIterator performSelect(Map<String, Object> values) {
				return new MongoDBIterator(buildFind(collectionName, query, values).projection(Document.parse(projection)), db);
			}
		}.scheduleSelect(resultId);
	}

	private FindIterable<Document> buildFind(String collectionName, String query, Map<String, Object> values) {
		StringSubstitutor sub = new StringSubstitutor(serialize(values));
		String resolvedQuery = sub.replace(query);
		MongoCollection<Document> coll = db.getCollection(collectionName);
		Document pattern = Document.parse(resolvedQuery);
		return coll.find(pattern);
	}

	private static Map<String,String> serialize(Map<String, Object> values) {
		return values.entrySet().stream()
				.collect(Collectors.toMap(
						Entry::getKey, 
						e -> serialize(e.getValue())
					)
				);
	}

	private static String serialize(Object obj) {
		if (obj == null) {
			return "null";
		}
		if (obj instanceof Integer || obj instanceof Boolean || obj instanceof Double) {
			return String.valueOf(obj);
		}
		else if (obj instanceof String) {
			return encodeJsonString((String) obj);
		}
		else if (obj instanceof Geometry) {
			return new GeoJSONWriter().write((Geometry)obj).toString();
		}
		else if (obj instanceof LocalDate) {
			// it's mixed around with instance, since timestamps only store seconds since epoch, which is fine for dates, but not so fine for tru timestamps
			long epoch = ((LocalDate)obj).atStartOfDay().toEpochSecond(ZoneOffset.UTC);
			return "{\"$timestamp\": {\"t\":" + Math.abs(epoch) + "\"i\": "+ (epoch >= 0 ? "1" : "-1") + "}}";
		}
		else if (obj instanceof Instant) {
			// it's mixed around with instance, since timestamps only store seconds since epoch, which is fine for dates, but not so fine for tru timestamps
			return "{\"$date\": {\"$numberLong\":" + ((Instant)obj).toEpochMilli() + "}}";
		}
		else if (obj instanceof UUID) {
			return "{ \"$binary\": {\"base64\": \"" + MakeUUID.uuidToBase64((UUID)obj) + "\", \"subType\": \"04\"}}";
			
		}
		else
			throw new RuntimeException("Query executor does not know how to serialize object of type " +obj.getClass());
	}

	private static String encodeJsonString(String obj) {
		try {
			StringWriter result = new StringWriter();
			try (JsonGenerator gen = JsonFactory.builder().build().createGenerator(result)) {
				gen.writeString(obj);
			}
			return result.toString();
		} catch (IOException e) {
			throw new RuntimeException("Not supposed to fail with writing to a string writer", e);
		}
	}

	protected static Document resolveQuery(ResultStore store, Supplier<GridFSBucket> gridFs, String query, Map<String, Object> values) {
		String resultQuery = new StringSubstitutor(serialize(values)).replace(query);
		Matcher m = BLOB_UUID.matcher(resultQuery);
		while (m.find()) {
			String blobName = m.group(1);
			InputStream blob = store.getBlob(blobName);
			if (blob != null) {
				// a new blob so we have to create it as well
				gridFs.get().uploadFromStream(blobName, blob);
			}
			else {
				try (GridFSDownloadStream existingBlob = gridFs.get().openDownloadStream(blobName)) {
                    if (existingBlob == null || existingBlob.getGridFSFile() == null) {
                        throw new RuntimeException("Referenced blob: " + blobName + " is not supplied and doesn't exist yet");
                    }
				}
				catch (MongoGridFSException e) {
                        throw new RuntimeException("Referenced blob: " + blobName + " is not supplied and doesn't exist yet", e);
				}
			}
		}
		
		return Document.parse(resultQuery);
	}
	
	private void scheduleUpdate(String collectionName, String doc, Map<String, Binding> bindings, BiConsumer<MongoCollection<Document>, Document> operation) {
		new UpdateExecutor(store, script, uuids, bindings, () -> "Mongo update" + doc) {
			
			@Override
			protected void performUpdate(Map<String, Object> values) {
				MongoCollection<Document> coll = db.getCollection(collectionName);
				Document parsedQuery = resolveQuery(store, () -> getGridFS(), doc, values);
				operation.accept(coll, parsedQuery);
			}
		}.scheduleUpdate();
	}
	

    @FunctionalInterface
    private interface TriConsumer<T, U, V> {

        void accept(T t, U u, V v);

    }
	private void executeFilteredUpdate(String collectionName, String filter, String doc, Map<String, Binding> bindings, TriConsumer<MongoCollection<Document>, Document, Document> operation) {
		new UpdateExecutor(store, script, uuids, bindings, () -> "Mongo: " + doc + " filter:" + filter) {
			
			@Override
			protected void performUpdate(Map<String, Object> values) {
				MongoCollection<Document> coll = db.getCollection(collectionName);
				Document parsedFilter = resolveQuery(store, () -> getGridFS(), filter, values);
				Document parsedQuery = resolveQuery(store, () -> getGridFS(),doc, values);
				operation.accept(coll, parsedFilter, parsedQuery);
			}
		}.scheduleUpdate();
	}
	
	private void scheduleGlobalUpdate(Consumer<MongoDatabase> operation) {
		new UpdateExecutor(store, script, uuids, Collections.emptyMap(), () -> "Global update: " + operation) {
			@Override
			protected void performUpdate(Map<String, Object> values) {
				operation.accept(db);
			}
		}.scheduleUpdate();
	}

	public void executeInsertOne(String dbName, String collectionName, String doc, Map<String, Binding> bindings) {
		scheduleUpdate(collectionName, doc, bindings, MongoCollection<Document>::insertOne);
	}
	
	public void executeFindAndUpdateOne(String dbName, String collectionName, String query, String update, Map<String, Binding> bindings) {
		executeFilteredUpdate(collectionName, query, update, bindings, MongoCollection<Document>::findOneAndUpdate);
	}
	
	public void executeFindAndUpdateMany(String dbName, String collectionName, String query, String update, Map<String, Binding> bindings) {
		executeFilteredUpdate(collectionName, query, update, bindings, MongoCollection<Document>::updateMany);
	}
	
	public void executeDeleteOne(String dbName, String collectionName, String query, Map<String, Binding> bindings) {
		scheduleUpdate(collectionName, query, bindings, MongoCollection<Document>::deleteOne);
	}
	
	public void executeDeleteMany(String dbName, String collectionName, String query, Map<String, Binding> bindings) {
		scheduleUpdate(collectionName, query, bindings, MongoCollection<Document>::deleteMany);
	}
	
	public void executeCreateCollection(String dbName, String collectionName) {
		scheduleGlobalUpdate(d -> d.createCollection(collectionName));
	}
	
	public void executeDropCollection(String dbName, String collectionName) {
		scheduleGlobalUpdate(d -> d.getCollection(collectionName).drop());
	}

	public void executeDropDatabase(String dbName) {
		scheduleGlobalUpdate(MongoDatabase::drop);
	}

	public void executeRenameCollection(String dbName, String collection, String newName) {
		scheduleGlobalUpdate(d -> d.getCollection(collection).renameCollection(new MongoNamespace(newName)));
	}

	public void executeCreateIndex(String collectionName, String keys) {
		scheduleGlobalUpdate(d -> d.getCollection(collectionName).createIndex(Document.parse(keys)));
	}


}
