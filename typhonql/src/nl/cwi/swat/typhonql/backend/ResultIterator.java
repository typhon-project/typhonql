package nl.cwi.swat.typhonql.backend;

public interface ResultIterator {
	void nextResult();
	boolean hasNextResult();
	String getCurrentId();
	Object getCurrentField(String name);
	void beforeFirst();
	String getType();
}
