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
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Set;
import java.util.UUID;
import java.util.function.BiConsumer;
import java.util.function.Consumer;
import java.util.function.Function;
import java.util.function.Supplier;
import java.util.regex.Matcher;
import java.util.stream.Collectors;

import org.apache.commons.text.StringSubstitutor;
import org.bson.BsonArray;
import org.bson.BsonBinary;
import org.bson.BsonBoolean;
import org.bson.BsonDateTime;
import org.bson.BsonDocument;
import org.bson.BsonDocumentWrapper;
import org.bson.BsonDouble;
import org.bson.BsonInt32;
import org.bson.BsonInt64;
import org.bson.BsonNull;
import org.bson.BsonString;
import org.bson.BsonTimestamp;
import org.bson.BsonValue;
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
import com.mongodb.client.model.IndexOptions;
import com.mongodb.client.model.InsertManyOptions;

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
	private final Map<String, DelayedInserts> bulkInserts;
	private final Map<String, BsonDocumentTemplate> parsedDocuments;
	
	private GridFSBucket getGridFS() {
		if (gridBucket == null) {
			return gridBucket = GridFSBuckets.create(db);
		}
		return gridBucket;
	}

	public MongoDBEngine(ResultStore store, TyphonSessionState state, List<Consumer<List<Record>>> script, Map<String, UUID> uuids, MongoDatabase db) {
		super(store, state, script, uuids);
		this.db = db;
		bulkInserts = state.getFromCache(MongoDBEngine.class.getName(), s -> {
			Map<String, DelayedInserts> result = new HashMap<>();
            state.addDelayedTask(() -> {
                result.values().forEach(DelayedInserts::execute);
            });
            return result;
		});
		parsedDocuments = state.getFromCache(MongoDBEngine.class.getName() + "$docs", s -> new HashMap<String, BsonDocumentTemplate>());
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
		if (obj instanceof Integer || obj instanceof Boolean || obj instanceof Double || obj instanceof Long) {
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
			return "{\"$timestamp\": {\"t\":" + Math.abs(epoch) + ", \"i\": "+ (epoch >= 0 ? "1" : "-1") + "}}";
		}
		else if (obj instanceof Instant) {
			// it's mixed around with instance, since timestamps only store seconds since epoch, which is fine for dates, but not so fine for tru timestamps
			return "{\"$date\": {\"$numberLong\":\"" + ((Instant)obj).toEpochMilli() + "\"}}";
		}
		else if (obj instanceof UUID) {
			return "{ \"$binary\": {\"base64\": \"" + MakeUUID.uuidToBase64((UUID)obj) + "\", \"subType\": \"04\"}}";
			
		}
		else
			throw new RuntimeException("Query executor does not know how to serialize object of type " +obj.getClass());
	}

	private BsonValue serializeBSON(Object obj) {
		if (obj == null) {
			return new BsonNull();
		}
		if (obj instanceof Integer) {
			return new BsonInt32((int) obj);
		}
		if (obj instanceof Long) {
			return new BsonInt64((long) obj);
		}
		if (obj instanceof Double) {
			return new BsonDouble((double) obj);
		}
		if (obj instanceof Boolean) {
			return new BsonBoolean((boolean) obj);
		}
		if (obj instanceof String) {
			return new BsonString((String) obj);
		}
		if (obj instanceof Geometry) {
			return BsonDocumentWrapper.parse(new GeoJSONWriter().write((Geometry)obj).toString());
		}
		else if (obj instanceof LocalDate) {
			// it's mixed around with instance, since timestamps only store seconds since epoch, which is fine for dates, but not so fine for tru timestamps
			return new BsonTimestamp(((LocalDate)obj).atStartOfDay().toEpochSecond(ZoneOffset.UTC));
		}
		else if (obj instanceof Instant) {
			// it's mixed around with instance, since timestamps only store seconds since epoch, which is fine for dates, but not so fine for tru timestamps
			return new BsonDateTime(((Instant)obj).toEpochMilli());
		}
		else if (obj instanceof UUID) {
			return new BsonBinary((UUID)obj);
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
	
	

	protected BsonDocument resolveQuery(ResultStore store, Supplier<GridFSBucket> gridFs, String query, Map<String, Object> values) {
		BsonDocumentTemplate result = parsedDocuments.computeIfAbsent(query, this::createBsonTemplate);
		return result.apply(s -> serializeBSON(values.get(s)), blobName -> {
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
		});
	}
	
	private BsonDocumentTemplate createBsonTemplate(String query) {
		return new BsonDocumentTemplate(BsonDocumentWrapper.asBsonDocument(Document.parse(query), db.getCodecRegistry()));
	}
	

	private void scheduleUpdate(String collectionName, String doc, Map<String, Binding> bindings, BiConsumer<MongoCollection<BsonDocument>, BsonDocument> operation) {
		new UpdateExecutor(store, script, uuids, bindings, () -> "Mongo update" + doc) {
			
			@Override
			protected void performUpdate(Map<String, Object> values) {
				MongoCollection<BsonDocument> coll = db.getCollection(collectionName, BsonDocument.class);
				BsonDocument parsedQuery = resolveQuery(store, () -> getGridFS(), doc, values);
				operation.accept(coll, parsedQuery);
			}
		}.scheduleUpdate();
	}
	

    @FunctionalInterface
    private interface TriConsumer<T, U, V> {

        void accept(T t, U u, V v);

    }
	private void executeFilteredUpdate(String collectionName, String filter, String doc, Map<String, Binding> bindings, TriConsumer<MongoCollection<BsonDocument>, BsonDocument, BsonDocument> operation) {
		new UpdateExecutor(store, script, uuids, bindings, () -> "Mongo: " + doc + " filter:" + filter) {
			
			@Override
			protected void performUpdate(Map<String, Object> values) {
				MongoCollection<BsonDocument> coll = db.getCollection(collectionName, BsonDocument.class);
				BsonDocument parsedFilter = resolveQuery(store, () -> getGridFS(), filter, values);
				BsonDocument parsedQuery = resolveQuery(store, () -> getGridFS(),doc, values);
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
		scheduleUpdate(collectionName, doc, bindings, (c, d) -> {
			if (store.hasExternalArguments()) {
				bulkInserts.computeIfAbsent(collectionName, n -> new DelayedInserts(c))
					.schedule(d);
			}
			else {
				c.insertOne(d);
			}
		});
	}
	
	public void executeFindAndUpdateOne(String dbName, String collectionName, String query, String update, Map<String, Binding> bindings) {
		executeFilteredUpdate(collectionName, query, update, bindings, MongoCollection<BsonDocument>::findOneAndUpdate);
	}
	
	public void executeFindAndUpdateMany(String dbName, String collectionName, String query, String update, Map<String, Binding> bindings) {
		executeFilteredUpdate(collectionName, query, update, bindings, MongoCollection<BsonDocument>::updateMany);
	}
	
	public void executeDeleteOne(String dbName, String collectionName, String query, Map<String, Binding> bindings) {
		scheduleUpdate(collectionName, query, bindings, MongoCollection<BsonDocument>::deleteOne);
	}
	
	public void executeDeleteMany(String dbName, String collectionName, String query, Map<String, Binding> bindings) {
		scheduleUpdate(collectionName, query, bindings, MongoCollection<BsonDocument>::deleteMany);
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

	public void executeCreateIndex(String collectionName, String indexName, String keys) {
		IndexOptions options = new IndexOptions().name(indexName);
		scheduleGlobalUpdate(d -> d.getCollection(collectionName).createIndex(Document.parse(keys), options));
	}

	public void executeDropIndex(String collectionName, String indexName) {
		scheduleGlobalUpdate(d -> d.getCollection(collectionName).dropIndex(indexName));
		
	}
	
	private static class DelayedInserts {
		private final List<BsonDocument> documents = new ArrayList<>();
		private final MongoCollection<BsonDocument> target;
		
		public DelayedInserts(MongoCollection<BsonDocument> target) {
			this.target = target;
		}
		
		public void execute() {
			target.insertMany(documents, new InsertManyOptions().bypassDocumentValidation(true).ordered(false));
		}
		
		public void schedule(BsonDocument doc) {
			documents.add(doc);
		}
	}


	private static class BsonDocumentTemplate {

		private final BsonDocument template;

		public BsonDocumentTemplate(BsonDocument template) {
			this.template = template;
		}
		
		private static BsonValue replace(BsonValue v, Function<String, BsonValue> serializer, Consumer<String> blobHandler) {
			if (v.isString()) {
				String s = v.asString().getValue();
				if (s.startsWith("${")) {
					v = serializer.apply(s.substring(2, s.length() - 1));
				}
				if (v.isString()) { // it might have changed again due to the apply before
					s = v.asString().getValue();
					if (s.startsWith("#blob:")) {
						blobHandler.accept(s.substring("#blob:".length()));
					}
				}
			}
			else if (v.isDocument()) {
				replaceDocument(v.asDocument(), serializer, blobHandler);
			}
			else if (v.isArray()) {
				replaceArray(v.asArray(), serializer, blobHandler);
			}
			return v;
		}
		
		private static void replaceArray(BsonArray ar, Function<String, BsonValue> serializer, Consumer<String> blobHandler) {
			for (int i = 0; i < ar.size(); i++) {
				BsonValue v = ar.get(i);
				BsonValue newV = replace(v, serializer, blobHandler);
				if (v != newV) {
					ar.set(i, newV);
				}
			}
		}
		
		private static void replaceDocument(BsonDocument root, Function<String, BsonValue> serializer, Consumer<String> blobHandler) {
			Iterator<Entry<String, BsonValue>> entries = root.entrySet().iterator();
			while (entries.hasNext()) {
				Entry<String, BsonValue> entry = entries.next();
				BsonValue v = entry.getValue();
				BsonValue newV = replace(v, serializer, blobHandler);
				if (v != newV) {
					entry.setValue(newV);
				}
			}
		}
		
		public BsonDocument apply(Function<String, BsonValue> serializer, Consumer<String> blobHandler) {
			BsonDocument root = template.clone();
			replaceDocument(root, serializer, blobHandler);
			return root;
		}
	}
}
