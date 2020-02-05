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
		ITree tree = new TyphonQLParser().parse("start__Request", BASE_URI,  query, new DefaultNodeFlattener<IConstructor, ITree, ISourceLocation>(), new UPTRNodeFactory(true));
		return ASTBuilder.buildRequest(tree);
	}
	

}
