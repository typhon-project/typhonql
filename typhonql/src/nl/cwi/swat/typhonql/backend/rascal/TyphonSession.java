package nl.cwi.swat.typhonql.backend.rascal;

import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Objects;
import java.util.UUID;
import java.util.function.Consumer;
import org.rascalmpl.interpreter.IEvaluatorContext;
import org.rascalmpl.interpreter.env.ModuleEnvironment;
import org.rascalmpl.interpreter.result.ICallableValue;
import org.rascalmpl.interpreter.result.ResultFactory;
import org.rascalmpl.interpreter.types.FunctionType;
import org.rascalmpl.interpreter.utils.RuntimeExceptionFactory;
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
import nl.cwi.swat.typhonql.backend.Record;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.client.DatabaseInfo;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

public class TyphonSession implements Operations {
	private static final TypeFactory TF = TypeFactory.getInstance();
	private final IValueFactory vf;
	
	public TyphonSession(IValueFactory vf) {
		this.vf = vf;
	}
	
	public ITuple newSession(IMap connections, IEvaluatorContext ctx) {
		return newSessionWrapper(connections, ctx).getTuple();
	}
	
	public SessionWrapper newSessionWrapper(IMap connections, IEvaluatorContext ctx) {
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
		return newSessionWrapper(mariaDbConnections, mongoConnections, ctx);
	}
	
	public SessionWrapper newSessionWrapper(List<DatabaseInfo> connections, IEvaluatorContext ctx) {
		Map<String, ConnectionData> mariaDbConnections = new HashMap<>();
		Map<String, ConnectionData> mongoConnections = new HashMap<>();
		for (DatabaseInfo db: connections) {
			switch (db.getDbType()) {
				case documentdb:
					mongoConnections.put(db.getDbName(), new ConnectionData(db));
					break;
				case relationaldb:
					mariaDbConnections.put(db.getDbName(), new ConnectionData(db));
					break;
                default:
                    throw new RuntimeException("Missing type: " + db.getDbType());
			}
		}
		return newSessionWrapper(mariaDbConnections, mongoConnections, ctx);
	}

	private SessionWrapper newSessionWrapper(Map<String, ConnectionData> mariaDbConnections, Map<String, ConnectionData> mongoConnections, IEvaluatorContext ctx) {
		//checkIsNotInitialized();
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
		FunctionType getResultType = (FunctionType)aliasedTuple.getFieldType("getResult");
		FunctionType getJavaResultType = (FunctionType)aliasedTuple.getFieldType("getJavaResult");
		FunctionType readAndStoreType = (FunctionType)aliasedTuple.getFieldType("readAndStore");
		FunctionType closeType = (FunctionType)aliasedTuple.getFieldType("done");
		FunctionType newIdType = (FunctionType)aliasedTuple.getFieldType("newId");
		
		// construct the session tuple
		ResultStore store  = new ResultStore();
		Map<String, String> uuids = new HashMap<>();
		List<Consumer<List<Record>>> script = new ArrayList<>();
		TyphonSessionState state = new TyphonSessionState();

		MariaDBOperations mariaDBOperations = new MariaDBOperations(mariaDbConnections);
		state.setMariaDBOperations(mariaDBOperations);
		MongoOperations mongoOperations = new MongoOperations(mongoConnections);
		state.setMongoOperations(mongoOperations);
		
		return new SessionWrapper(
			vf.tuple(
					makeGetResult(store, script, state, getResultType, ctx),
					makeGetJavaResult(store, script, state, getJavaResultType, ctx),
					makeReadAndStore(store, script, state, readAndStoreType, ctx),
					makeClose(store, state, closeType, ctx),
					makeNewId(uuids, state, newIdType, ctx),
					mariaDBOperations.newSQLOperations(store, script, state, uuids, ctx, vf, TF),
					mongoOperations.newMongoOperations(store, script, state, uuids, ctx, vf, TF)),
            state);
	}

	private IValue makeNewId(Map<String, String> uuids, TyphonSessionState state, FunctionType newIdType,
			IEvaluatorContext ctx) {
		return makeFunction(ctx, state, newIdType, args -> {
			String idName = ((IString) args[0]).getValue();
			String uuid = UUID.randomUUID().toString();
			uuids.put(idName, uuid);
			return ResultFactory.makeResult(TF.stringType(), vf.string(uuid), ctx);
		});
	}

	private ICallableValue makeClose(ResultStore store, TyphonSessionState state, FunctionType closeType,
			IEvaluatorContext ctx) {
		return makeFunction(ctx, state, closeType, args -> {
			close(state);
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}

	private ResultTable computeResultTable(ResultStore store, List<Consumer<List<Record>>> script, IValue[] args) {
		List<Path> paths = new ArrayList<>();

		IList pathsList = (IList) args[0];
		Iterator<IValue> iter = pathsList.iterator();

		while (iter.hasNext()) {
			ITuple tuple = (ITuple) iter.next();
			paths.add(toPath(tuple));
		}

		// List<EntityModel> models = EntityModelReader.fromRascalRelation(types,
		// modelsRel);
		// WorkingSet ws = store.computeResult(resultName, labels.toArray(new
		// String[0]), models.toArray(new EntityModel[0]));
		try {
			ResultTable rt = store.computeResultTable(script, paths);
			return rt;
		} catch (RuntimeException e) {
			throw RuntimeExceptionFactory.javaException(e, null, null);
		}
	}

	private ICallableValue makeGetResult(ResultStore store, List<Consumer<List<Record>>> script,
			TyphonSessionState state, FunctionType getResultType, IEvaluatorContext ctx) {
		return makeFunction(ctx, state, getResultType, args -> {
			// alias ResultTable = tuple[list[str] columnNames, list[list[value]] values];
			return ResultFactory.makeResult(
					TF.tupleType(new Type[] { TF.listType(TF.stringType()), TF.listType(TF.listType(TF.valueType())) },
							new String[] { "columnNames", "values" }),
					state.getResult().toIValue(), ctx);
		});
	}

	private ICallableValue makeGetJavaResult(ResultStore store, List<Consumer<List<Record>>> script,
			TyphonSessionState state, FunctionType getResultType, IEvaluatorContext ctx) {
		return makeFunction(ctx, state, getResultType, args -> {
			// alias ResultTable = tuple[list[str] columnNames, list[list[value]] values];
			return ResultFactory.makeResult(TF.externalType(TF.valueType()), state.getResult(), ctx);
		});
	}

	private ICallableValue makeReadAndStore(ResultStore store, List<Consumer<List<Record>>> script,
			TyphonSessionState state, FunctionType readAndStoreType, IEvaluatorContext ctx) {
		return makeFunction(ctx, state, readAndStoreType, args -> {
			ResultTable rt = computeResultTable(store, script, args);
			state.setResult(rt);
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}

	private Path toPath(ITuple path) {
		IList pathLst = (IList) path.get(3);
		Iterator<IValue> vs = pathLst.iterator();
		List<String> fields = new ArrayList<String>();
		while (vs.hasNext()) {
			fields.add(((IString) (vs.next())).getValue());
		}
		String dbName = ((IString) path.get(0)).getValue();
		String var = ((IString) path.get(1)).getValue();
		String entityType = ((IString) path.get(2)).getValue();
		return new Path(dbName, var, entityType, fields.toArray(new String[0]));
	}

	public void close(TyphonSessionState state) {
		state.close();

	}

}