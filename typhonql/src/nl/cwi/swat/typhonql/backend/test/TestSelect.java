package nl.cwi.swat.typhonql.backend.test;

import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;

import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.EntityModel;
import nl.cwi.swat.typhonql.backend.MariaDBEngine;
import nl.cwi.swat.typhonql.backend.MongoDBEngine;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.TyphonType;
import nl.cwi.swat.typhonql.workingset.Entity;
import nl.cwi.swat.typhonql.workingset.WorkingSet;

public class TestSelect {
/*
	 
	runSession(TyphonQL quert, Session session)
	
	run(TyphonQL query) {
	  Session s = getSession();
	  return runSession(s);
	 
	}
	
	alias Session = tuple[
	     void (str) execute,
	     void done()
	     WorkingSet doneWithResult()
			
	
		// Rascal bridge, Tijs asks for a new session, I get a tuple with function types for executeSelect... and then in
		// the Java side I fill it in with callables that call the actual things
		new AbstractFunction() {
			
			@Override
			public boolean isStatic() {
				// TODO Auto-generated method stub
				return false;
			}
			
			@Override
			public ICallableValue cloneInto(Environment arg0) {
				// TODO Auto-generated method stub
				return null;
			}
			
			@Override
			public boolean isDefault() {
				// TODO Auto-generated method stub
				return false;
			}
		};
		new ICallableValue() {
			
			@Override
			public Type getType() {
				// TODO Auto-generated method stub
				return null;
			}
			
			@Override
			public boolean isStatic() {
				// TODO Auto-generated method stub
				return false;
			}
			
			@Override
			public boolean hasVarArgs() {
				// TODO Auto-generated method stub
				return false;
			}
			
			@Override
			public boolean hasKeywordArguments() {
				// TODO Auto-generated method stub
				return false;
			}
			
			@Override
			public IEvaluator<Result<IValue>> getEval() {
				// TODO Auto-generated method stub
				return null;
			}
			
			@Override
			public int getArity() {
				// TODO Auto-generated method stub
				return 0;
			}
			
			@Override
			public ICallableValue cloneInto(Environment arg0) {
				// TODO Auto-generated method stub
				return null;
			}
			
			@Override
			public Result<IValue> call(IRascalMonitor arg0, Type[] arg1, IValue[] arg2, Map<String, IValue> arg3) {
				// TODO Auto-generated method stub
				return null;
			}
			
			@Override
			public Result<IValue> call(Type[] arg0, IValue[] arg1, Map<String, IValue> arg2) {
				// TODO Auto-generated method stub
				return null;
			}
		};
		
		vf.tuple(f1, f2)
		*/
		
	public static void main(String[] args) {
		
		ResultStore store = new ResultStore();
		
		MariaDBEngine e1 = new MariaDBEngine(store, "localhost", 3306, "Inventory", "root", "example");
		MongoDBEngine e2 = new MongoDBEngine(store, "localhost", 27018, "Reviews", "admin", "admin");
		
		e1.executeSelect("user", "select u.`User.name` as `u.User.name`,  u.`User.@id` as `u.User.@id` from User u where u.`User.name` = \"Pablo\"");
		LinkedHashMap<String, Binding> map1 = new LinkedHashMap<String, Binding>();
		map1.put("user_id", new Binding("user", "u", "User"));
		e2.executeFind("review", "Review", "{ user: \"${user_id}\" }", map1);
		
		// Binding needs an extra argument `attribute` for inspecting attributes in the entities that conform the stored results
		LinkedHashMap<String, Binding> map2 = new LinkedHashMap<String, Binding>();
		map2.put("product_id", new Binding("review", "dummy", "Review", "product"));
		
		e1.executeSelect("result", 
				"select p.`Product.@id` as `p.Product.@id`, p.`Product.name` as `p.Product.name`, p.`Product.description` as `p.Product.description` from Product p where p.`Product.@id` = ?", map2);
		
		//List<Entity> result = buildResult("result", );
		
		/*
		for (Entity e: store.getEntities("user")) {
			System.out.println(e);
		}
		
		for (Entity e: store.getEntities("review")) {
			System.out.println(e);
		}*/
		
		System.out.println("Final Result:");
		
		Map<String, TyphonType> attributes = new HashMap<>();
		attributes.put("description",TyphonType.STRING);
		attributes.put("name", TyphonType.STRING);
		WorkingSet result = store.computeResult("result", new String[] { "product" }, new EntityModel("Product", attributes));
		
		for (Entity e : result.get("product")) {
			System.out.println(e);
		}

		
	}
}
