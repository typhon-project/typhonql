package nl.cwi.swat.typhonql.backend.rascal;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Objects;
import java.util.UUID;

import org.rascalmpl.interpreter.IEvaluatorContext;
import org.rascalmpl.interpreter.env.ModuleEnvironment;
import org.rascalmpl.interpreter.result.ICallableValue;
import org.rascalmpl.interpreter.result.ResultFactory;
import org.rascalmpl.interpreter.types.FunctionType;

import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.IInteger;
import io.usethesource.vallang.IList;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeFactory;
import io.usethesource.vallang.type.TypeStore;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

public class TyphonSession implements Operations {
	private static final TypeFactory TF = TypeFactory.getInstance();
	private final IValueFactory vf;
	
	private ResultTable storedResult = null;
	private ResultStore store = null;
	private STATE state = STATE.NOT_INITIALIZED;
	
	public TyphonSession(IValueFactory vf) {
		this.vf = vf;
	}

	public ITuple newSession(IMap connections, IEvaluatorContext ctx) {
		checkIsNotInitialized();
		// borrow the type store from the module, so we don't have to build the function type ourself
        ModuleEnvironment aliasModule = ctx.getHeap().getModule("lang::typhonql::Session");
        if (aliasModule == null) {
        	throw new IllegalArgumentException("Missing my own module");
        }
        TypeStore ts = aliasModule.getStore();
		Type aliasedTuple = Objects.requireNonNull(ctx.getCurrentEnvt().lookupAlias("Session"));
		while (aliasedTuple.isAliased()) {
			aliasedTuple = aliasedTuple.getAliased();
		}

		// get the function types
		FunctionType readType = (FunctionType)aliasedTuple.getFieldType("read");
		FunctionType readAndStoreType = (FunctionType)aliasedTuple.getFieldType("readAndStore");
		FunctionType closeType = (FunctionType)aliasedTuple.getFieldType("done");
		FunctionType newIdType = (FunctionType)aliasedTuple.getFieldType("newId");
		
		Map<String, ConnectionData> mariaDbConnections = new HashMap<>();
		Map<String, ConnectionData> mongoConnections = new HashMap<>();
		
		Iterator<Entry<IValue, IValue>> connIter = connections.entryIterator();
		
		while (connIter.hasNext()) {
			Entry<IValue, IValue> entry = connIter.next();
			String dbName = ((IString) entry.getKey()).getValue();
			IConstructor cons = (IConstructor) entry.getValue();
			String host = ((IString) cons.get("host")).getValue();
			int port = ((IInteger) cons.get("port")).intValue();
			String user = ((IString) cons.get("user")).getValue();
			String password = ((IString) cons.get("password")).getValue();
			ConnectionData data = new ConnectionData(host, port, user, password);
			if (cons.getName().equals("sqlConnection"))
				mariaDbConnections.put(dbName, data);
			else if (cons.getName().equals("mongoConnection"))
				mongoConnections.put(dbName, data);
				
		}
		// construct the session tuple
		store  = new ResultStore();
		Map<String, String> uuids = new HashMap<>();
		state = STATE.ACTIVE;
		return vf.tuple(
			makeRead(store, readType, ctx),
			makeReadAndStore(store, readAndStoreType, ctx),
            makeClose(store, closeType, ctx),
            makeNewId(uuids, newIdType, ctx),
            new MariaDBOperations(mariaDbConnections).newSQLOperations(store, uuids, ctx, vf, TF),
            new MongoOperations(mongoConnections).newMongoOperations(store, uuids, ctx, vf, TF)
		);
	}
	

	private void checkIsNotInitialized() {
		if (state != STATE.NOT_INITIALIZED)
			throw new RuntimeException("Cannot create session, since it has been already initialized");
	}

	private IValue makeNewId(Map<String, String> uuids, FunctionType newIdType, IEvaluatorContext ctx) {
		return makeFunction(ctx, newIdType, args -> {
			checkIsActive("make new id");
			String idName = ((IString) args[0]).getValue();
			String uuid = UUID.randomUUID().toString();
			uuids.put(idName, uuid);
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}

	private void checkIsActive(String oper) {
		if (state != STATE.ACTIVE)
			throw new RuntimeException("Operation " + oper + " cannor be executed on a non-active session");
	}

	private ICallableValue makeClose(ResultStore store, FunctionType closeType, IEvaluatorContext ctx) {
		return makeFunction(ctx, closeType, args -> {
			checkIsActive("close");
			close();
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}
	
	private ResultTable computeResultTable(ResultStore store, IValue[] args) {
		List<Path> paths = new ArrayList<>();
		
		IList pathsList = (IList) args[0];
		Iterator<IValue> iter = pathsList.iterator();
		
		while (iter.hasNext()) {
			ITuple tuple = (ITuple) iter.next();
			paths.add(toPath(tuple));
		}
		
		//List<EntityModel> models = EntityModelReader.fromRascalRelation(types, modelsRel);
		//WorkingSet ws = store.computeResult(resultName, labels.toArray(new String[0]), models.toArray(new EntityModel[0]));
		ResultTable rt = store.computeResultTable(paths);
		return rt;
	}
	
	private ICallableValue makeRead(ResultStore store, FunctionType readType, IEvaluatorContext ctx) {
		return makeFunction(ctx, readType, args -> {
			checkIsActive("read");
			ResultTable rt = computeResultTable(store, args);
			// alias ResultTable =  tuple[list[str] columnNames, list[list[value]] values];
 			return ResultFactory.makeResult(TF.tupleType(new Type[] { TF.listType(TF.stringType()), TF.listType(TF.listType(TF.valueType()))}, 
 					new String[]{ "columnNames", "values"}), rt.toIValue(), ctx);
		});
	}
	
	private ICallableValue makeReadAndStore(ResultStore store, FunctionType readAndStoreType, IEvaluatorContext ctx) {
		return makeFunction(ctx, readAndStoreType, args -> {
			checkIsActive("read");
			ResultTable rt = computeResultTable(store, args);
			this.storedResult = rt;
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}

	private Path toPath(ITuple path) {
		IList pathLst = (IList) path.get(2);
		Iterator<IValue> vs = pathLst.iterator();
		List<String> fields = new ArrayList<String>();
		while (vs.hasNext()) {
			fields.add(((IString)(vs.next())).getValue());
		}
		String label = ((IString) path.get(0)).getValue();
		String entityType = ((IString) path.get(1)).getValue();
		return new Path(label,
			entityType,
			fields.toArray(new String[0]));
	}

	public ResultTable getStoredResult() {
		return storedResult;
	}
	
	public void close() {
		state = STATE.CLOSE;
		storedResult = null;
		
	}

	private static enum STATE { NOT_INITIALIZED, ACTIVE, CLOSE }


}
