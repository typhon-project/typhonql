package nl.cwi.swat.typhonql.backend.test;

import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;

import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.EntityModel;
import nl.cwi.swat.typhonql.backend.Field;
import nl.cwi.swat.typhonql.backend.MariaDBEngine;
import nl.cwi.swat.typhonql.backend.ResultStore;
import nl.cwi.swat.typhonql.backend.TyphonType;
import nl.cwi.swat.typhonql.workingset.Entity;
import nl.cwi.swat.typhonql.workingset.WorkingSet;

public class TestSelect3 {
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
		
		Map<String, String> uuids = new HashMap<String, String>();
		
		MariaDBEngine e1 = new MariaDBEngine(store, uuids, "localhost", 3306, "Inventory", "root", "example");
		
		e1.executeSelect("user", "select u.`User.name` as `u.User.name`,  u.`User.@id` as `u.User.@id` from User u where u.`User.name` = \"Claudio\"");
		LinkedHashMap<String, Binding> map1 = new LinkedHashMap<String, Binding>();
		map1.put("user_id", new Field("user", "u", "User"));
		
		
		e1.executeSelect("user2", "select u.`User.name` as `u.User.name`,  u.`User.@id` as `u.User.@id` from User u where u.`User.@id` = ${user_id}",  map1);
		
		System.out.println("Final Result:");
		
		Map<String, TyphonType> attributes = new HashMap<>();
		
		attributes.put("name", TyphonType.STRING);
		
		WorkingSet result = store.computeResult("user2", new String[] { "u" }, new EntityModel("User", attributes));
		
		for (Entity e : result.get("u")) {
			System.out.println(e);
		}

		
	}
}
