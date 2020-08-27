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
				for (PlaceHolderOrUUID obj : x.getRefs()) {
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
				+ "products: [#someProductRef],"
				+ "position: #point(1.0 2.0),"
				+ "area: #polygon((1.0 1.0, 1.0 2.0, 2.0 2.0, 1.0 1.0))"
				+ "}").toCharArray());
	}

}
