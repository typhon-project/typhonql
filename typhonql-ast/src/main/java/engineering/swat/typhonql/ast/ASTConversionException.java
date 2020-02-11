package engineering.swat.typhonql.ast;

import org.rascalmpl.values.uptr.ITree;

public class ASTConversionException extends Exception {

	/**
	 * 
	 */
	private static final long serialVersionUID = 7884139547318693397L;

	public ASTConversionException(String msg) {
		super(msg);
	}

	public ASTConversionException(String msg, Throwable e) {
		super(msg, e);
	}


	public ASTConversionException(ITree tree) {
		super("Failing on : "+ tree.toString());
	}
	

}
