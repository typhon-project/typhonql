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

package nl.cwi.swat.typhonql.backend.rascal;


import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Map.Entry;
import java.util.function.Function;

import org.rascalmpl.eclipse.util.ThreadSafeImpulseConsole;
import org.rascalmpl.interpreter.IEvaluatorContext;
import org.rascalmpl.interpreter.control_exceptions.MatchFailed;
import org.rascalmpl.interpreter.env.Environment;
import org.rascalmpl.interpreter.result.AbstractFunction;
import org.rascalmpl.interpreter.result.ICallableValue;
import org.rascalmpl.interpreter.result.Result;
import org.rascalmpl.interpreter.types.FunctionType;

import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.IList;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.type.Type;
import nl.cwi.swat.typhonql.backend.Binding;
import nl.cwi.swat.typhonql.backend.Field;
import nl.cwi.swat.typhonql.backend.GeneratedIdentifier;
import nl.cwi.swat.typhonql.backend.MultipleBindings;

public interface Operations {
	// no support for kw params yet 
	default ICallableValue makeFunction(IEvaluatorContext ctx, TyphonSessionState state, FunctionType typ, Function<IValue[], Result<IValue>> body) {
		return new AbstractFunction(ctx.getCurrentAST(), ctx.getEvaluator(), typ, Collections.emptyList(), false, ctx.getCurrentEnvt()) {
			
			@Override
			public boolean isStatic() {
				return false;
			}
			
			@Override
			public ICallableValue cloneInto(Environment env) {
				// should not happen, we are not part of an environment
				return null;
			}
			
			@Override
			public boolean isDefault() {
				return false;
			}
			
			@Override
			public Result<IValue> call(Type[] argTypes, IValue[] argValues, Map<String, IValue> keyArgValues) throws MatchFailed {
				checkIsActive(state);
				try {
					return body.apply(argValues);
				} catch (NullPointerException e) {
					e.printStackTrace(new PrintWriter(ThreadSafeImpulseConsole.INSTANCE.getWriter()));
					throw e;
				}
			}
		};
		
	}
	
	default void checkIsActive(TyphonSessionState state) {
		if (state.isFinalized())
			throw new RuntimeException("Operation cannot be executed on a non-active session");
	}
	
	default Map<String, Binding> rascalToJavaBindings(IMap bindings) {
		Map<String, Binding> bindingsMap = new HashMap<>();
		Iterator<Entry<IValue, IValue>> iter = bindings.entryIterator();
		while (iter.hasNext()) {
			Entry<IValue, IValue> kv = iter.next();
			IString param = (IString) kv.getKey();
			IConstructor cons = (IConstructor) kv.getValue();
			Binding b = null;
			if (cons.getName().contentEquals("field")) {
				b = new Field(((IString) cons.get(0)).getValue() ,
					((IString) cons.get(1)).getValue(), ((IString) cons.get(2)).getValue(), ((IString) cons.get(3)).getValue());
			}
			else if (cons.getName().contentEquals("generatedId")) {
				b = new GeneratedIdentifier(((IString) cons.get(0)).getValue());
			}
			bindingsMap.put(param.getValue(), b);
		}
		return bindingsMap;
	}
	
	default List<Path> rascalToJavaSignature(IList signature) {
		List<Path> result = new ArrayList<>();
		Iterator<IValue> iter = signature.iterator();
		while (iter.hasNext()) {
			ITuple t = (ITuple) iter.next();
			IString dbName = (IString) t.get(0);
			IString var = (IString) t.get(1);
			IString entityType = (IString) t.get(2);
			IList path = (IList) t.get(3);
			List<String> pathList = new ArrayList<String>();
			Iterator<IValue> vs = path.iterator();
			while (vs.hasNext()) {
				pathList.add(((IString) vs.next()).getValue());
			}
				
			result.add(new Path(dbName.getValue(), var.getValue(), entityType.getValue(), pathList.toArray(new String[0])));
		}
		return result;
	}
	
	default Optional<MultipleBindings> rascaltoJavaMultipleBindings(IConstructor cons) {
		if (cons.getName().contentEquals("bindings")) {
			IList rVarNames = (IList) cons.get(0);
			IList rVarTypes = (IList) cons.get(1);
			IList rValues = (IList) cons.get(2);
			List<String> varNames = toJavaStringList(rVarNames);
			List<String> varTypes = toJavaStringList(rVarTypes);
			List<List<String>> values = new ArrayList<List<String>>();
			Iterator<IValue> iter = rValues.iterator();
			while (iter.hasNext()) {
				IList row = (IList) iter.next();
				values.add(toJavaStringList(row));
			}
			return Optional.of(new MultipleBindings(varNames, varTypes, values));
		} else {
			return Optional.empty();
		}
	}

	default List<String> toJavaStringList(IList rVarNames) {
		Iterator<IValue> iter = rVarNames.iterator();
		List<String> r = new ArrayList<String>();
		while (iter.hasNext()) 
			r.add(((IString) iter.next()).getValue());
		return r;
				
	}
}
