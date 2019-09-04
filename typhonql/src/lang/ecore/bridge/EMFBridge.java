package lang.ecore.bridge;

import java.io.PrintWriter;
import java.net.URISyntaxException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.eclipse.emf.common.notify.Notifier;
import org.eclipse.emf.common.util.EList;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.EFactory;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EPackage;
import org.eclipse.emf.ecore.EStructuralFeature;
import org.eclipse.emf.ecore.util.EcoreUtil;
import org.rascalmpl.debug.IRascalMonitor;
//import org.rascalmpl.eclipse.nature.ProjectEvaluatorFactory;
import org.rascalmpl.interpreter.Evaluator;
import org.rascalmpl.interpreter.IEvaluator;
import org.rascalmpl.interpreter.NullRascalMonitor;
import org.rascalmpl.interpreter.TypeReifier;
import org.rascalmpl.interpreter.env.Environment;
import org.rascalmpl.interpreter.env.GlobalEnvironment;
import org.rascalmpl.interpreter.env.ModuleEnvironment;
import org.rascalmpl.interpreter.result.AbstractFunction;
import org.rascalmpl.interpreter.result.ICallableValue;
import org.rascalmpl.interpreter.result.Result;
import org.rascalmpl.interpreter.result.ResultFactory;
import org.rascalmpl.interpreter.types.FunctionType;
import org.rascalmpl.interpreter.types.RascalTypeFactory;
import org.rascalmpl.interpreter.utils.RuntimeExceptionFactory;
import org.rascalmpl.values.ValueFactoryFactory;
import org.rascalmpl.values.uptr.RascalValueFactory;

import io.usethesource.vallang.IBool;
import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.IInteger;
import io.usethesource.vallang.IList;
import io.usethesource.vallang.IReal;
import io.usethesource.vallang.ISourceLocation;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.ITuple;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.type.Type;
import io.usethesource.vallang.type.TypeFactory;
import io.usethesource.vallang.type.TypeStore;

public class EMFBridge {

	private static TypeFactory tf = TypeFactory.getInstance();
	private static Map<String, Evaluator> bundleEvals = new HashMap<>();

	// The signature of the `function` should be
	// Patch (Loader[&T] load);

//	public static ChangeCommand runRascal(String bundleId, EObject obj, String module, String function) {
//		if (!(bundleEvals.containsKey(bundleId))) {
//			GlobalEnvironment heap = new GlobalEnvironment();
//		    Evaluator eval = new Evaluator(ValueFactoryFactory.getValueFactory(), new PrintWriter(System.err), new PrintWriter(System.out), 
//		    		new ModuleEnvironment("$emfbridge$", heap), heap);
//		    ProjectEvaluatorFactory.getInstance().initializeBundleEvaluator(Platform.getBundle(bundleId), eval);
//			bundleEvals.put(bundleId, eval);
//		}
//		Evaluator eval = bundleEvals.get(bundleId);
//		IRascalMonitor mon = new NullRascalMonitor();
//		eval.doImport(mon, module);
//		URI uri = EcoreUtil.getURI(obj);
//		ISourceLocation src;
//		try {
//			src = eval.getValueFactory().sourceLocation(uri.scheme(), uri.authority(), uri.path(), uri.query(), uri.fragment());
//		} catch (URISyntaxException e) {
//			throw RuntimeExceptionFactory.malformedURI(uri.toString(), null, null);
//		}
//		ITuple patch = (ITuple) eval.call(function, new IValue[] { new ObtainModelClosure(obj, src, eval) });
//		
//		return patch(obj, patch);
//	}
	
//	@SuppressWarnings("unchecked")
//	public static ChangeCommand patch(EObject root, ITuple patch) {
//		EPackage pkg = root.eClass().getEPackage();
//		EFactory fact = pkg.getEFactoryInstance();
//		Map<IConstructor, EObject> cache = new HashMap<>();
//		
//		List<Notifier> roots = new ArrayList<>();
//		roots.add(root);
//		
//		
//		ChangeCommand result = new ChangeCommand(roots) {
//
//			@Override
//			protected void doExecute() {
//				//root.eSetDeliver(false);
//				
//				for (IValue v: (IList)patch.get(1)) {
//					ITuple idEdit = (ITuple)v;
//					IConstructor id = (IConstructor) idEdit.get(0);
//					IConstructor edit = (IConstructor) idEdit.get(1);
//					
//					if (edit.getName().equals("create")) {
//						String clsName = ((IString)edit.get("class")).getValue();
//						EClass eCls = (EClass) pkg.getEClassifier(clsName);
//						EObject obj = fact.create(eCls);
//						cache.put(id, obj);
//					}
//					else {
//						EObject obj = lookup(root, id, cache);
//
//						if (edit.getName().equals("destroy")) {
//							;
//							//cmds.add(DeleteCommand.create(domain, obj));
//						}
//						else {
//							String fieldName = ((IString)edit.get("field")).getValue();
//							
//							EStructuralFeature field = obj.eClass().getEStructuralFeature(fieldName);
//							if (edit.getName().equals("put")) {
//								Object val = value2obj(edit.get("val"), root, cache);
//								obj.eSet(field, val);
//							 }
//							else if (edit.getName().equals("unset")) {
//								obj.eUnset(field);
//							}
//							else {
//								EList<Object> lst = (EList<Object>)obj.eGet(field);
//								int pos = ((IInteger)edit.get("pos")).intValue();
//								if (edit.getName().equals("ins")) {
//									lst.add(pos, value2obj(edit.get("val"), root, cache));
//								}
//								else if (edit.getName().equals("del")) {
//									lst.remove(pos);
//								}
//								else {
//									throw RuntimeExceptionFactory.illegalArgument(edit, null, null);
//								}
//							}
//						}
//					}
//					
//				}
//				
//				//root.eSetDeliver(true);
//			}
//			
//		};
//		return result;
//	}
	
	/*
	 *  patch object root according to `patch`.
	 *  fill cache (mapping ids to EObjects) and newIds in the process
	 *  return the new root
	 *  NB: root may be null, when we're creating from scratch.
	 */
	@SuppressWarnings({"unchecked", "unused"})
	private static EObject patch(EPackage pkg, EObject root, ITuple patch, Map<IConstructor, EObject> cache, Set<IConstructor> newIds) {
		EFactory fact = pkg.getEFactoryInstance();
		
		for (IValue v: (IList)patch.get(1)) {
			ITuple idEdit = (ITuple)v;
			IConstructor id = (IConstructor) idEdit.get(0);
			IConstructor edit = (IConstructor) idEdit.get(1);
			if (edit.getName().equals("create")) {
				String clsName = ((IString)edit.get("class")).getValue();
				EClass eCls = (EClass) pkg.getEClassifier(clsName);
				EObject obj = fact.create(eCls);
				cache.put(id, obj);
				newIds.add(id);
			}
			else {
				EObject obj = lookup(root, id, cache);
				String fieldName = ((IString)edit.get("field")).getValue();
				EStructuralFeature field = obj.eClass().getEStructuralFeature(fieldName);

				if (edit.getName().equals("destroy")) {
					// this deletes obj from all containers and references to it
					// but that's ok, because deletes are always at the end. 
					EcoreUtil.delete(obj);
				}
				else if (edit.getName().equals("put")) {
					Object val = value2obj(edit.get("val"), root, cache);
					obj.eSet(field, val);
				}
				else if (edit.getName().equals("unset")) {
					obj.eUnset(field);
				}
				else {
					List<Object> lst = (List<Object>)obj.eGet(field);
					int pos = ((IInteger)edit.get("pos")).intValue();
					
					if (edit.getName().equals("ins")) {
						lst.add(pos, value2obj(edit.get("val"), root, cache));
					}
					else if (edit.getName().equals("del")) {
						lst.remove(pos);
					}
					else {
						throw RuntimeExceptionFactory.illegalArgument(edit, null, null);
					}
				}
			}
		}
		
		return lookup(root, (IConstructor)patch.get(0), cache);
	}

	private static Object value2obj(IValue v, EObject root, Map<IConstructor, EObject> cache) {
		// todo: should check against actual Id type.
		Type type = v.getType();
		if (type.isAbstractData() && ((IConstructor)v).getName().equals("id")) {
			return lookup(root, (IConstructor)v, cache);
		}
		if (type.isInteger()) {
			return ((IInteger)v).intValue();
		}
		if (type.isString()) {
			return ((IString)v).getValue();
		}
		if (type.isReal()) {
			return ((IReal)v).floatValue();
		}
		if (type.isBool()) {
			return ((IBool)v).getValue();
		}
		return null;
	}
	
	private static EObject lookup(EObject root, IConstructor id, Map<IConstructor, EObject> cache) {
		if (cache.containsKey(id)) {
			return cache.get(id);
		}
		
		// created things always are in the cache, so we can assume
		// loc ids in this case.
		ISourceLocation loc = (ISourceLocation)id.get(0);
		
		EObject obj = root.eResource().getEObject(loc.getFragment());
		cache.put(id, obj);
		return obj;
	}
	
	
	private static class ObtainModelClosure extends AbstractFunction {
		
		private EObject model;
		private ISourceLocation src;
		
		private static final FunctionType myType;
		
		static {
			RascalTypeFactory rtf = RascalTypeFactory.getInstance();
			Type param = tf.parameterType("T", tf.nodeType());
			myType = (FunctionType) rtf.functionType(param, tf.tupleType(rtf.reifiedType(param)), tf.tupleEmpty());
		}

		public ObtainModelClosure(EObject model, ISourceLocation src, IEvaluator<Result<IValue>> eval) {
			super(null, eval, myType, Collections.emptyList(), false, eval.getCurrentEnvt());
			this.model = model;
			this.src = src;
		}
		
		@Override
		public ICallableValue cloneInto(Environment env) {
			return null;
		}
		
		@Override
		public boolean isStatic() {
			return false;
		}
		
		@Override
		public boolean isDefault() {
			return false;
		}
		
		@Override
		public IConstructor encodeAsConstructor() {
			IValueFactory vf = eval.getValueFactory();
			return vf.constructor(RascalValueFactory.Function_Function, vf.sourceLocation("file:///unknown"));
		}
		
		@Override
		public Result<IValue> call(IRascalMonitor arg0, Type[] arg1, IValue[] arg2, Map<String, IValue> arg3) {
			return call(arg1, arg2, arg3);
		}
		
		@Override
		public Result<IValue> call(Type[] arg0, IValue[] args, Map<String, IValue> kws) {
			// TODO: cache the reifiedType and type store
			// it should always be the same for every call because we're tied to 1 meta model anyway. 
			
			IValue reifiedType = args[0];
			TypeStore ts = new TypeStore(); // start afresh
			IValueFactory values = getEval().getValueFactory();
			Type rt = new TypeReifier(values).valueToType((IConstructor) reifiedType, ts);

			Convert.declareRefType(ts);
			
			IValue val = Convert.obj2value(model, rt, values, ts, src);
			return ResultFactory.makeResult(rt, val, getEval());
		}

		

	}
}
