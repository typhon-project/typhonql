package lang.typhonql.mongodb;

import org.bson.Document;
import org.rascalmpl.interpreter.Evaluator;
import org.rascalmpl.interpreter.IEvaluatorContext;

import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;

import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import lang.typhonql.Queryable;

public class TyphonQL2MongoDB implements Queryable {

	private final IEvaluatorContext eval;
	private IValueFactory vf;
	private MongoDatabase mongoDb;

	public TyphonQL2MongoDB(MongoDatabase mongoDb, IValueFactory vf, Evaluator eval) {
		this.mongoDb = mongoDb;
		this.eval = eval;
		this.vf = vf;
	}

	public Object query(String query) {
		IMap m = (IMap) eval.getEvaluator().call("typhon2mongodb", vf.string(query));
		Object result = null;
		for (IValue k : m) {
			addToResult(mongoDb.getCollection(((IString) k).getValue()), (IConstructor) m.get(k), result);
		}
		return result;
	}

	private void addToResult(MongoCollection<Document> collection, IConstructor method, Object result) {
		switch (method.getName()) {
		case "find": ; 
		default: throw new UnsupportedOperationException(method.toString());
		}
	}
	
	
	

}
