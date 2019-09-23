package nl.cwi.swat.typhonql;

import java.sql.Connection;
import java.sql.Date;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.rascalmpl.interpreter.utils.RuntimeExceptionFactory;

import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;
import com.mongodb.client.result.UpdateResult;

import io.usethesource.vallang.IBool;
import io.usethesource.vallang.IDateTime;
import io.usethesource.vallang.IInteger;
import io.usethesource.vallang.IList;
import io.usethesource.vallang.IListWriter;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IMapWriter;
import io.usethesource.vallang.IReal;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;

public class Bridge {
	
	private final IValueFactory vf;

	public Bridge(IValueFactory vf) {
		this.vf = vf;
	}
	
	
	private static Connection getJDBCConnection(IString polystoreId, IString dbName) {
		Connection con = (Connection) Connections.getInstance().getConnection(polystoreId.getValue(), dbName.getValue());
		if (con == null) {
			throw RuntimeExceptionFactory.illegalArgument(dbName, null, null, "No SQL connection for database");
		}
		return con;
	}
	
	private static MongoDatabase getMongoDB(IString polystoreId, IString dbName) {
		MongoDatabase db = (MongoDatabase) Connections.getInstance().getConnection(polystoreId.getValue(), dbName.getValue());
		if (db == null) {
			throw RuntimeExceptionFactory.illegalArgument(dbName, null, null, "No MongoDB for database");
		}
		return db;
	}

	public IList executeQuery(IString polystoreId, IString dbName, IString sql, IList arguments) {
		throw new AssertionError("not yet implemented");
	}

	
	public IList executeQuery(IString polystoreId, IString dbName, IString sql) {
		Connection con = getJDBCConnection(polystoreId, dbName);
		try {
			Statement stat = con.createStatement();
			ResultSet rs = stat.executeQuery(sql.getValue());
			IListWriter w = vf.listWriter();
			ResultSetMetaData meta = rs.getMetaData();
			while (rs.next()) {
				IMapWriter record = vf.mapWriter();
				for (int i = 1; i <= meta.getColumnCount(); i++) {
					Object val = rs.getObject(i);
					if (val != null) {
						record.put(vf.string(meta.getColumnName(i)), prim2value(val));
					} // else, don't add
				}
				w.append(record.done());
			}
			stat.close();
			return w.done();
		} catch (SQLException e) {
			throw RuntimeExceptionFactory.illegalArgument(sql, null, null, e.getMessage());
		}
	}
	

	public IInteger executeUpdate(IString polystoreId, IString dbName, IString sql) {
		Connection con = getJDBCConnection(polystoreId, dbName);
		try {
			Statement stat = con.createStatement();
			int result = stat.executeUpdate(sql.getValue());
			return vf.integer(result);
		} catch (SQLException e) {
			throw RuntimeExceptionFactory.illegalArgument(sql, null, null, e.getMessage());
		}
	}
	
	public void createCollection(IString polystoreId, IString dbName, IString collectionName) {
		MongoDatabase db = getMongoDB(polystoreId, dbName);
		db.createCollection(collectionName.getValue());
	}
	
	public void drop(IString polystoreId, IString dbName, IString collectionName) {
		MongoDatabase db = getMongoDB(polystoreId, dbName);
		MongoCollection<Document> coll = db.getCollection(collectionName.getValue());
		coll.drop();
	}
	
	public IList find(IString polystoreId, IString dbName, IString collectionName, IMap pattern) {
		MongoDatabase db = getMongoDB(polystoreId, dbName);
		MongoCollection<Document> coll = db.getCollection(collectionName.getValue());
		IListWriter result = vf.listWriter();
		for (Document doc: coll.find((Document)value2doc(pattern))) {
			result.append(doc2value(doc));
		}
		return result.done();
	}

	public void deleteOne(IString polystoreId, IString dbName, IString collectionName, IMap doc) {
		MongoDatabase db = getMongoDB(polystoreId, dbName);
		MongoCollection<Document> coll = db.getCollection(collectionName.getValue());
		coll.deleteOne((Document) value2doc(doc));
	}

	public void insertOne(IString polystoreId, IString dbName, IString collectionName, IMap doc) {
		MongoDatabase db = getMongoDB(polystoreId, dbName);
		MongoCollection<Document> coll = db.getCollection(collectionName.getValue());
		coll.insertOne((Document) value2doc(doc));
	}
	
	
	public ITuple updateOne(IString polystoreId,IString dbName, IString collectionName, IMap pattern, IMap update) {
		MongoDatabase db = getMongoDB(polystoreId, dbName);
		MongoCollection<Document> coll = db.getCollection(collectionName.getValue());
		UpdateResult result = coll.updateOne((Document)value2doc(pattern), (Document)value2doc(update));
		return vf.tuple(vf.integer(result.getMatchedCount()), vf.integer(result.getModifiedCount()));
	}

	
	public ITuple updateMany(IString polystoreId, IString dbName, IString collectionName, IMap pattern, IMap update) {
		MongoDatabase db = getMongoDB(polystoreId, dbName);
		MongoCollection<Document> coll = db.getCollection(collectionName.getValue());
		UpdateResult result = coll.updateMany((Document)value2doc(pattern), (Document)value2doc(update));
		return vf.tuple(vf.integer(result.getMatchedCount()), vf.integer(result.getModifiedCount()));
	}
	
	
	@SuppressWarnings({"rawtypes" })
	private IValue doc2value(Object doc) {
		if (doc instanceof Document) {
			IMapWriter w = vf.mapWriter();
			for (Map.Entry<String, Object> entry: ((Document)doc).entrySet()) {
				String k = entry.getKey();
				Object v = entry.getValue();
				IValue value = doc2value(v);
				w.put(vf.string(k), value);
			}
			return w.done();
		}
		
		if (doc instanceof List) {
			IListWriter w = vf.listWriter();
			for (Object obj: ((List)doc)) {
				w.append(doc2value(obj));
			}
			return w.done();
		}
		
		return prim2value(doc);
	}
	
	private Object value2doc(IValue value) {
		if (value.getType().isMap()) {
			Document doc = new Document();
			IMap map = (IMap)value;
			for (IValue k: map) {
				doc.append(((IString)k).getValue(), value2doc(map.get(k)));
			}
			return doc;
		}
		
		if (value.getType().isList()) {
			List<Object> lst = new ArrayList<Object>();
			for (IValue v: ((IList)value)) {
				lst.add(value2doc(v));
			}
			return lst;
		}
		
		return value2prim(value);
	}
	
	private Object value2prim(IValue value) {
		Type t = value.getType();
		
		if (t.isString()) {
			return ((IString)value).getValue();
		}
		
		if (t.isInteger()) {
			return ((IInteger)value).intValue();
		}
		
		if (t.isBool()) {
			return ((IBool)value).getValue();
		}
		
		if (t.isReal()) {
			return ((IReal)value).doubleValue();
		}
		
		throw RuntimeExceptionFactory.illegalArgument(value, null, null, 
				"Cannot convert Rascal value to Java object");
	}


	private IValue prim2value(Object obj) {
		assert obj != null;
		
		if (obj instanceof String) {
			return vf.string((String)obj);
		}
		if (obj instanceof Integer) {
			return vf.integer(((Integer)obj).longValue());
		}
		if (obj instanceof Boolean) {
			return vf.bool(((Boolean)obj).booleanValue());
		}
		if (obj instanceof Double) {
			return vf.real(((Double)obj).doubleValue());
		}
		if (obj instanceof Float) {
			return vf.real(((Float)obj).doubleValue());
		}
		if (obj instanceof ObjectId) {
			return vf.string(((ObjectId)obj).toHexString());
		}
		
		throw RuntimeExceptionFactory.illegalArgument(vf.string(obj.getClass().getName()), null, null, 
				"Cannot convert Java object to Rascal value");
	}

}
