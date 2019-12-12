package nl.cwi.swat.typhonql.backend;

public interface ResultIterator {
	void nextResult();
	boolean hasNextResult();
	String getCurrentId(String type);
	Object getCurrentField(String type, String name);
	void beforeFirst();
}
