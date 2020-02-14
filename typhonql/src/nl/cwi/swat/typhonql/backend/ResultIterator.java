
package nl.cwi.swat.typhonql.backend;

public interface ResultIterator {
	void nextResult();
	boolean hasNextResult();
	String getCurrentId(String label, String type);
	Object getCurrentField(String label, String type, String name);
	void beforeFirst();
}
