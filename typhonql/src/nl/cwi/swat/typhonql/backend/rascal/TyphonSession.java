package nl.cwi.swat.typhonql.backend.rascal;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
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
import io.usethesource.vallang.ISet;
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
	
	public TyphonSession(IValueFactory vf) {
		this.vf = vf;
	}

	public ITuple newSession(IMap connections, IEvaluatorContext ctx) {
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
		ResultStore store = new ResultStore();
		Map<String, String> uuids = new HashMap<>();
		return vf.tuple(
			makeRead(store, readType, ctx),
            makeClose(store, closeType, ctx),
            makeNewId(uuids, newIdType, ctx),
            new MariaDBOperations(mariaDbConnections).newSQLOperations(store, uuids, ctx, vf, TF),
            new MongoOperations(mongoConnections).newMongoOperations(store, uuids, ctx, vf, TF)
		);
	}
	

	private IValue makeNewId(Map<String, String> uuids, FunctionType newIdType, IEvaluatorContext ctx) {
		return makeFunction(ctx, newIdType, args -> {
			String idName = ((IString) args[0]).getValue();
			String uuid = UUID.randomUUID().toString();
			uuids.put(idName, uuid);
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}

	private ICallableValue makeClose(ResultStore store, FunctionType closeType, IEvaluatorContext ctx) {
		return makeFunction(ctx, closeType, args -> {
			store.clear();
			return ResultFactory.makeResult(TF.voidType(), null, ctx);
		});
	}
	
	private ICallableValue makeRead(ResultStore store, FunctionType readType, IEvaluatorContext ctx) {
		return makeFunction(ctx, readType, args -> {
			String resultName = ((IString) args[0]).getValue();
			List<Path> paths = new ArrayList<>();
			
			IList pathsList = (IList) args[1];
			Iterator<IValue> iter = pathsList.iterator();
			
			while (iter.hasNext()) {
				ITuple tuple = (ITuple) iter.next();
				paths.add(toPath(tuple));
			}
			
			//List<EntityModel> models = EntityModelReader.fromRascalRelation(types, modelsRel);
			//WorkingSet ws = store.computeResult(resultName, labels.toArray(new String[0]), models.toArray(new EntityModel[0]));
			ResultTable rt = store.computeResultTable(resultName, paths);
			
 			ByteArrayOutputStream os = new ByteArrayOutputStream();
 			
 			try {
 				rt.serializeJSON(os);
				os.flush();
			} catch (IOException e) {
				throw new RuntimeException(e);
			}
 			
 			String json = new String(os.toByteArray());
 			return ResultFactory.makeResult(TF.stringType(), vf.string(json), ctx);
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

}
