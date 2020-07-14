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

import java.net.URI;
import java.net.URISyntaxException;
import org.rascalmpl.parser.gtd.result.out.DefaultNodeFlattener;
import org.rascalmpl.parser.uptr.UPTRNodeFactory;
import org.rascalmpl.values.uptr.ITree;
import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.ISourceLocation;

public class TyphonQLASTParser {
	
	private static final URI BASE_URI;
	static {
		try {
			BASE_URI = new URI("api-input:///");
		} catch (URISyntaxException e) {
			throw new RuntimeException(e);
		}
		
	}
	public static Request parseTyphonQLRequest(char[] query) throws ASTConversionException {
		ITree tree = new TyphonQLParser().parse("start__Request", BASE_URI,  query, new DefaultNodeFlattener<IConstructor, ITree, ISourceLocation>(), new UPTRNodeFactory(false));
		return ASTBuilder.buildRequest(tree);
	}
	

}
