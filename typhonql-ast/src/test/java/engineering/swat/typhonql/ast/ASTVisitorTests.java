package engineering.swat.typhonql.ast;

import static org.junit.jupiter.api.Assertions.assertEquals;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import engineering.swat.typhonql.ast.Expr.RefLst;
import engineering.swat.typhonql.ast.Obj.Literal;
import engineering.swat.typhonql.ast.Statement.Insert;

public class ASTVisitorTests {
	
	@Test
	public void testRegularVisitor() throws Exception {
		Request ast = parseAST();
		String productId = ast.getStm().accept(new NullASTVisitor<String>() {
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
			public String visitExprRefLst(RefLst x) {
				for (UUID obj : x.getRefs()) {
					return obj.getString();
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
		assertEquals("#someProductRef", productId);
	}
	
	@Test
	void testName() throws Exception {
		Request ast = parseAST();
		Set<String> ints = new HashSet<>();
		List<Integer> listSize = new ArrayList<>();

		ast.accept(new TopDownASTVisitor() {
			@Override
			public Void visitExprRefLst(RefLst x) {
				listSize.add(x.getRefs().size());
				// call super method to continue visiting entries of this list
				// else return null
				return super.visitExprRefLst(x);
			}
			
			@Override
			public Void visitIntLexical(engineering.swat.typhonql.ast.Int.Lexical x) {
				ints.add(x.toString());
				return null;
			}
			
		});
		assertEquals(Collections.singleton("32"), ints);
		assertEquals(Collections.singletonList(1), listSize);
	}
	
	

	private Request parseAST() throws ASTConversionException {
		return TyphonQLASTParser.parseTyphonQLRequest(("insert Order { "
				+ "totalAmount: 32, "
				+ "products: [#someProductRef]"
				+ "}").toCharArray());
	}

}
