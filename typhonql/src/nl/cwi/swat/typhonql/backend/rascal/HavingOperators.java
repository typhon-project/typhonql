package nl.cwi.swat.typhonql.backend.rascal;

public class HavingOperators {
	
	// TODO: supplant with all expressions as soon as we support them.

	
	public static boolean eq(Object x, Object y) {
		return x.equals(y);
	}


	public static boolean neq(Object x, Object y) {
		return !eq(x, y);
	}
	
	@SuppressWarnings({ "rawtypes", "unchecked" })
	private static int myCompare(Object x, Object y) {
		Comparable c1 = (Comparable)x;
		Comparable c2 = (Comparable)y;
		return c1.compareTo(c2);
	}


	public static boolean geq(Object x, Object y) {
		return myCompare(x, y) >= 0;
	}

	public static boolean leq(Object x, Object y) {
		return myCompare(x, y) <= 0;
	}

	public static boolean lt(Object x, Object y) {
		return myCompare(x, y) < 0;
	}
	
	public static boolean gt(Object x, Object y) {
		return myCompare(x, y) > 0;
	}
	
	public static boolean and(Object x, Object y) {
		return ((Boolean)x) && ((Boolean)y);
	}
	
	public static boolean or(Object x, Object y) {
		return ((Boolean)x) || ((Boolean)y);
	}



}
