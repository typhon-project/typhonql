// based on ASTBuilder out of rascal, licensed under EPL
package engineering.swat.typhonql.ast;

import java.lang.reflect.Constructor;
import java.lang.reflect.InvocationTargetException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.rascalmpl.values.ValueFactoryFactory;
import org.rascalmpl.values.uptr.TreeAdapter;
import io.usethesource.vallang.IList;
import io.usethesource.vallang.IListWriter;
import io.usethesource.vallang.IValue;

public class ASTBuilder {
	
	public static Request buildRequest(org.rascalmpl.values.uptr.ITree tree) throws ASTConversionException {
		if (TreeAdapter.isAppl(tree)) {
			return buildSort(tree, "Request");
		}
		if (TreeAdapter.isAmb(tree)) {
			throw new ASTConversionException("Parse tree is amb");
		}
		throw new IllegalArgumentException("Tree is of invalid type");
	}
 

	@SuppressWarnings("unchecked")
	private static <T extends AbstractAST> T buildSort(org.rascalmpl.values.uptr.ITree parseTree, String sort) throws ASTConversionException {
		if (TreeAdapter.isAppl(parseTree)) {
			org.rascalmpl.values.uptr.ITree tree = TreeAdapter.getStartTop(parseTree);

			if (sortName(tree).equals(sort)) {
				return (T) buildValue(tree);
			}
		} 
		else if (TreeAdapter.isAmb(parseTree)) {
			throw new ASTConversionException(parseTree);
		}

		throw new IllegalArgumentException("This is not a " + sort +  ": " + parseTree);
	}

	private static AbstractAST buildValue(IValue arg) throws ASTConversionException  {
		org.rascalmpl.values.uptr.ITree tree = (org.rascalmpl.values.uptr.ITree) arg;

		if (TreeAdapter.isList(tree)) {
			throw new IllegalArgumentException("buildValue should not be called on a list");
		}

		if (TreeAdapter.isAmb(tree)) {
			throw new ASTConversionException(tree);
		}

		if (!TreeAdapter.isAppl(tree)) {
			throw new UnsupportedOperationException();
		}	

		if (TreeAdapter.isLexical(tree)) {
			if (TreeAdapter.isRascalLexical(tree)) {
				return buildLexicalNode(tree);
			}
			return buildLexicalNode((org.rascalmpl.values.uptr.ITree) ((IList) ((org.rascalmpl.values.uptr.ITree) arg).get("args")).get(0));
		}
		
		if (TreeAdapter.isOpt(tree)) {
			IList args = TreeAdapter.getArgs(tree);
			if (args.isEmpty()) {
			    return null;
			}
			return buildValue(args.get(0));
		    
		}

		return buildContextFreeNode((org.rascalmpl.values.uptr.ITree) arg);
	}

	private static List<AbstractAST> buildList(org.rascalmpl.values.uptr.ITree in) throws ASTConversionException  {
		IList args = TreeAdapter.getListASTArgs(in);
		List<AbstractAST> result = new ArrayList<AbstractAST>(args.length());
		for (IValue arg: args) {
			result.add(buildValue(arg));
		}
		return result;
	}

	private static AbstractAST buildContextFreeNode(org.rascalmpl.values.uptr.ITree tree) throws ASTConversionException  {
		String constructorName = TreeAdapter.getConstructorName(tree);
		if (constructorName == null) {
			throw new IllegalArgumentException("All Rascal productions should have a constructor name: " + TreeAdapter.getProduction(tree));
		}

		String cons = capitalize(constructorName);
		String sort = capitalize(sortName(tree));

		if (sort.length() == 0) {
			throw new IllegalArgumentException("Could not retrieve sort name for " + tree);
		}

		IList args = getASTArgs(tree);
		int arity = args.length();
		Object actuals[] = new Object[arity+2];
		actuals[0] = TreeAdapter.getLocation(tree);
		actuals[1] = tree;

		int i = 2;
		for (IValue arg : args) {
			org.rascalmpl.values.uptr.ITree argTree = (org.rascalmpl.values.uptr.ITree) arg;

			if (TreeAdapter.isList(argTree)) {
				actuals[i] = buildList((org.rascalmpl.values.uptr.ITree) arg);
			}
			else {
				actuals[i] = buildValue(arg);
			}
			i++;
		}

		return callMakerMethod(sort, cons, actuals, null);
	}

	private static AbstractAST buildLexicalNode(org.rascalmpl.values.uptr.ITree tree) throws ASTConversionException {
		String sort = capitalize(sortName(tree));

		if (sort.length() == 0) {
			throw new IllegalArgumentException("could not retrieve sort name for " + tree);
		}
		Object actuals[] = new Object[] { TreeAdapter.getLocation(tree), tree, new String(TreeAdapter.yield(tree)) };

		return callMakerMethod(sort, "Lexical", actuals, null);
	}



	private static IList getASTArgs(org.rascalmpl.values.uptr.ITree tree) {
		IList children = TreeAdapter.getArgs(tree);
		IListWriter writer = ValueFactoryFactory.getValueFactory().listWriter();
		
                for (int i = 0; i < children.length(); i++) {
			org.rascalmpl.values.uptr.ITree kid = (org.rascalmpl.values.uptr.ITree) children.get(i);
			if (!TreeAdapter.isLiteral(kid) && !TreeAdapter.isCILiteral(kid) && !TreeAdapter.isEmpty(kid)) {
				writer.append(kid);	
			} 
			// skip layout
			i++;
		}

		return writer.done();
	}

	private static String sortName(org.rascalmpl.values.uptr.ITree tree) {
		if (TreeAdapter.isAppl(tree)) { 
			return TreeAdapter.getSortName(tree);
		}
		if (TreeAdapter.isAmb(tree)) {
			// all alternatives in an amb cluster have the same sort
			return sortName((org.rascalmpl.values.uptr.ITree) TreeAdapter.getAlternatives(tree).iterator().next());
		}
		return "";
	}

	private static String capitalize(String sort) {
		if (sort.length() == 0) {
			return sort;
		}
		if (sort.length() > 1) {
			return Character.toUpperCase(sort.charAt(0)) + sort.substring(1);
		}

		return sort.toUpperCase();
	}


	private final static Map<String, Constructor<?>> astConstructors = new ConcurrentHashMap<>();
	private final static ClassLoader classLoader = ASTBuilder.class.getClassLoader();

	private static AbstractAST callMakerMethod(String sort, String cons, Object actuals[], Object keywordActuals[]) throws ASTConversionException {
		Constructor<?> constructor = astConstructors.computeIfAbsent(sort + '$' + cons, name -> {
			try {
                Class<?> clazz = classLoader.loadClass("engineering.swat.typhonql.ast." + name);
                Constructor<?> result = clazz.getConstructors()[0];
                result.setAccessible(true);
                return result;
			} catch (SecurityException | IllegalArgumentException | ClassNotFoundException e) {
				System.err.println("Cannot find constructor: " + name);
				e.printStackTrace(System.err);
				return null;
			}
		});
		if (constructor == null) {
			throw new ASTConversionException("Unexpected error in finding constructor");
		}
		try {
			return (AbstractAST) constructor.newInstance(actuals);
		} catch (SecurityException | IllegalArgumentException | IllegalAccessException | InvocationTargetException | InstantiationException e) {
			throw new ASTConversionException("Unexpected error in construction: " + sort + "::" + cons + "(" + actuals.length +")", e);
		}
	}

}
