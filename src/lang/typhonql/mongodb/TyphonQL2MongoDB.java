package lang.typhonql.mongodb;

import org.bson.Document;
import org.rascalmpl.interpreter.IEvaluatorContext;

import com.mongodb.client.FindIterable;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;

import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;

public class TyphonQL2MongoDB  {

	private final IEvaluatorContext eval;
	private IValueFactory vf;
	private MongoDatabase mongoDb;

	public TyphonQL2MongoDB(MongoDatabase mongoDb, IValueFactory vf, IEvaluatorContext eval) {
		this.mongoDb = mongoDb;
		this.eval = eval;
		this.vf = vf;
	}

	public Object query(String query) {
		IMap m = (IMap) eval.getEvaluator().call("lang::typhonql::mongodb::TyphonQL2MongoDB::typhon2mongodb", vf.string(query));
		Object result = null;
		for (IValue k : m) {
			executeMethod(mongoDb.getCollection(((IString) k).getValue()), (IConstructor) m.get(k), result);
		}
		return result;
	}

	private void executeMethod(MongoCollection<Document> collection, IConstructor method, Object result) {
		switch (method.getName()) {
		case "find": 
			switch (method.arity()) {
			case 0: FindIterable<Document> obj = collection.find();
			case 1: //find(DBObject query)
				break;
			case 2: //find(DBObject query, DBObject projection)	
			case 4: //find(DBObject query, DBObject projection, int numToSkip, int batchSize)	
				
			}
			
		default: throw new UnsupportedOperationException(method.toString());
		}
	}
	
	
	

}
