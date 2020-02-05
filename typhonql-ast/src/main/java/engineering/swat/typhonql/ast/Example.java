package engineering.swat.typhonql.ast;

import engineering.swat.typhonql.ast.Expr.Lst;
import engineering.swat.typhonql.ast.Obj.Literal;
import engineering.swat.typhonql.ast.Statement.Insert;

public class Example {
	public static void main(String[] args) throws ASTConversionException {
		System.err.println("Parsing query");
		Request ast = TyphonQLASTParser.parseTyphonQLRequest(("insert Order { "
				+ "totalAmount: 32, "
				+  "products: [Product { name: \"TV\" } ]"
				+ " }").toCharArray());
		System.err.println("Visiting query");
		String productName = ast.getStm().accept(new NullASTVisitor<String>() {
			@Override
			public String visitStatementInsert(Insert x) {
				for (Obj o : x.getObjs()) {
					for (KeyVal keyVal : o.getKeyVals()) {
                        if (keyVal.getKey().getString().equals("products")) {
                            return keyVal.getValue().accept(this);
                        }
					}
				}
				return null;
			}
			
			@Override
			public String visitExprLst(Lst x) {
				for (Obj obj : x.getEntries()) {
					String result = obj.accept(this);
					if (result != null) {
						return result;
					}
				}
				return null;
			}
			
			@Override
			public String visitObjLiteral(Literal x) {
				if (x.getEntity().getString().equals("Product")) {
					for (KeyVal keyVal : x.getKeyVals()) {
						if (keyVal.getKey().getString().equals("name") && keyVal.getValue().isStr()) {
							return keyVal.getValue().getStrValue().getString();
						}
					}
				}
				return null;
			}
		});
		System.out.println("Found product name: " + productName);
		System.out.flush();
		
		System.err.println("Or using default top-down visitor");
		ast.accept(new TopDownASTVisitor() {
			@Override
			public Void visitExprLst(Lst x) {
				System.out.println("Got a list: " + x.getEntries().size());
				System.out.flush();
				// call super method to continue visiting entries of this list
				// else return null
				return super.visitExprLst(x);
			}
			
			@Override
			public Void visitIntLexical(engineering.swat.typhonql.ast.Int.Lexical x) {
				System.out.println("found int: " + x.getString());
				System.out.flush();
				return super.visitIntLexical(x);
			}
			
		});
		
	}

}
