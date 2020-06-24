package nl.cwi.swat.typhonql.backend.rascal;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
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

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.IInteger;
import io.usethesource.vallang.IList;
import io.usethesource.vallang.IListWriter;
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
import nl.cwi.swat.typhonql.backend.Runner;
import nl.cwi.swat.typhonql.backend.cassandra.CassandraOperations;
import nl.cwi.swat.typhonql.client.DatabaseInfo;
import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

public class TyphonSession implements Operations {
	private static final TypeFactory TF = TypeFactory.getInstance();
	private final IValueFactory vf;

	public TyphonSession(IValueFactory vf) {
		this.vf = vf;
	}

	public ITuple newSession(IMap connections, IMap fileMap, IEvaluatorContext ctx) {
		return newSessionWrapper(connections, fileMap, ctx).getTuple();
	}
	
	public SessionWrapper newSessionWrapper(IMap connections, IMap fileMap, IEvaluatorContext ctx) {
		Map<String, ConnectionData> mariaDbConnections = new HashMap<>();
		Map<String, ConnectionData> mongoConnections = new HashMap<>();
		Map<String, ConnectionData> cassandraConnections = new HashMap<>();

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
			switch (cons.getName()) {
				case "mariaConnection":
					mariaDbConnections.put(dbName, data);
					break;
				case "mongoConnection":
                    mongoConnections.put(dbName, data);
                    break;
				case "cassandraConnection":
                    cassandraConnections.put(dbName, data);
                    break;
			}
		}
		Map<String, InputStream> actualFileMap = new HashMap<>();
		Iterator<Entry<IValue, IValue>> it = fileMap.entryIterator();
		while (it.hasNext()) {
			Entry<IValue, IValue> cur = it.next();
			String key = ((IString)cur.getKey()).getValue();
			String value = ((IString)cur.getValue()).getValue();
			actualFileMap.put(key, new ByteArrayInputStream(value.getBytes(StandardCharsets.UTF_8)));
		}
		return newSessionWrapper(mariaDbConnections, mongoConnections, cassandraConnections, actualFileMap, ctx);
	}

	public SessionWrapper newSessionWrapper(List<DatabaseInfo> connections, Map<String, InputStream> fileMap, IEvaluatorContext ctx) {
		Map<String, ConnectionData> mariaDbConnections = new HashMap<>();
		Map<String, ConnectionData> mongoConnections = new HashMap<>();
		Map<String, ConnectionData> cassandraConnections = new HashMap<>();
		for (DatabaseInfo db : connections) {
			switch (db.getDbms().toLowerCase()) {
			case "mongodb":
				mongoConnections.put(db.getDbName(), new ConnectionData(db));
				break;
			case "mariadb":
				mariaDbConnections.put(db.getDbName(), new ConnectionData(db));
				break;
			case "cassandra":
				cassandraConnections.put(db.getDbName(), new ConnectionData(db));
				break;
			case "neo4j":
				break;
			default:
				throw new RuntimeException("Missing type: " + db.getDbms());
			}
		}
		return newSessionWrapper(mariaDbConnections, mongoConnections, cassandraConnections, fileMap, ctx);
	}

	private SessionWrapper newSessionWrapper(Map<String, ConnectionData> mariaDbConnections,
			Map<String, ConnectionData> mongoConnections, Map<String, ConnectionData> cassandraConnections, Map<String, InputStream> fileMap, IEvaluatorContext ctx) {
		// checkIsNotInitialized();
		// borrow the type store from the module, so we don't have to build the function
		// type ourself
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
		FunctionType getResultType = (FunctionType) aliasedTuple.getFieldType("getResult");
		FunctionType getJavaResultType = (FunctionType) aliasedTuple.getFieldType("getJavaResult");
		FunctionType readAndStoreType = (FunctionType) aliasedTuple.getFieldType("readAndStore");
		FunctionType doneType = (FunctionType) aliasedTuple.getFieldType("finish");
		FunctionType closeType = (FunctionType) aliasedTuple.getFieldType("done");
		FunctionType newIdType = (FunctionType) aliasedTuple.getFieldType("newId");

		// construct the session tuple
		ResultStore store = new ResultStore(fileMap);
		Map<String, String> uuids = new HashMap<>();
		List<Consumer<List<Record>>> script = new ArrayList<>();
		List<Runnable> updates = new ArrayList<>();
		TyphonSessionState state = new TyphonSessionState();

		MariaDBOperations mariaDBOperations = new MariaDBOperations(mariaDbConnections);
		MongoOperations mongoOperations = new MongoOperations(mongoConnections);
		CassandraOperations cassandra = new CassandraOperations(cassandraConnections);
		state.addOpperations(mariaDBOperations);
		state.addOpperations(mongoOperations);
		state.addOpperations(cassandra);

		return new SessionWrapper(vf.tuple(makeGetResult(state, getResultType, ctx),
				makeGetJavaResult(state, getJavaResultType, ctx),
				makeReadAndStore(store, script, state, readAndStoreType, ctx),
				makeFinish(script, updates, state, doneType, ctx),
				makeClose(store, state, closeType, ctx),
				makeNewId(uuids, state, newIdType, ctx),
				mariaDBOperations.newSQLOperations(store, script, updates, state, uuids, ctx, vf),
				mongoOperations.newMongoOperations(store, script, updates, state, uuids, ctx, vf),
				cassandra.buildOperations(store, script, updates, state, uuids, ctx, vf)
				), state);
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

		try {
			ResultTable rt = Runner.computeResultTable(script, paths);
			return rt;
		} catch (RuntimeException e) {
			throw RuntimeExceptionFactory.javaException(e, null, null);
		}
	}

	private ICallableValue makeGetResult(TyphonSessionState state, FunctionType getResultType,
			IEvaluatorContext ctx) {
		return makeFunction(ctx, state, getResultType, args -> {
			// alias ResultTable = tuple[list[str] columnNames, list[list[value]] values];
			try (ByteArrayOutputStream json = new ByteArrayOutputStream()) {
				state.getResult().serializeJSON(json);
                return ResultFactory.makeResult(
                        TF.tupleType(new Type[] { TF.listType(TF.stringType()), TF.listType(TF.listType(TF.valueType())) },
                                new String[] { "columnNames", "values" }),
                        parseTable(json.toByteArray()), ctx);
			} catch (IOException e) {
				throw new RuntimeException(e);
			}
		});
	}

	private IValue parseTable(byte[] json) {
		try {
			ObjectMapper objectMapper = new ObjectMapper();
			JsonNode tbl = objectMapper.readTree(json);
			JsonNode columns = tbl.get("columnNames");
			if (columns == null || !columns.isArray()) {
				throw new RuntimeException("Incorrect result table json");
			}
			IListWriter columnList = vf.listWriter();
			columns.iterator().forEachRemaining(c -> columnList.append(vf.string(c.asText())));

			IListWriter valueList = vf.listWriter();
			tbl.get("values").iterator().forEachRemaining(row -> {
				IListWriter rowList = vf.listWriter();
				row.iterator().forEachRemaining(c -> rowList.append(toIValue(c)));
				valueList.append(rowList.done());
			});
			return vf.tuple(columnList.done(), valueList.done());
		} catch (IOException e) {
			throw new RuntimeException(e);
		}
	}

	private IValue toIValue(JsonNode c) {
		if (c.isNumber()) {
			if (c.canConvertToInt()) {
				return vf.integer(c.asInt());
			}
			return vf.real(c.asDouble());
		}
		else if (c.isBoolean()) {
			return vf.bool(c.asBoolean());
		}
		else if (c.isNull()) {
			return vf.set();
		}
		else if (c.isTextual()) {
			return vf.string(c.asText());
		}
		else {
			throw new RuntimeException("Cannot convert " + c + " into an IValue");
		}
	}

	private ICallableValue makeGetJavaResult(TyphonSessionState state, FunctionType getResultType,
			IEvaluatorContext ctx) {
		return makeFunction(ctx, state, getResultType, args -> {
			return ResultFactory.makeResult(TF.externalType(TF.valueType()), state.getResult(), ctx);
		});
	}

	private ICallableValue makeReadAndStore(ResultStore store, List<Consumer<List<Record>>> script,
			TyphonSessionState state, FunctionType readAndStoreType, IEvaluatorContext ctx) {
		return makeFunction(ctx, state, readAndStoreType, args -> {
			ResultTable rt = computeResultTable(store, script, args);
			state.setResult(rt);
			script.clear();
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}

	private ICallableValue makeFinish(List<Consumer<List<Record>>> script, List<Runnable> updates, TyphonSessionState state,
			FunctionType readAndStoreType, IEvaluatorContext ctx) {
		return makeFunction(ctx, state, readAndStoreType, args -> {
			Runner.executeUpdates(script, updates);
			script.clear();
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
		try {
			state.close();
		} catch (Exception e) {
			if (e instanceof RuntimeException) {
				throw (RuntimeException)e;
			}
			throw new RuntimeException("Failure to close state", e);
		}

	}

}
