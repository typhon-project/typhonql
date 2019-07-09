package nl.cwi.swat.typhonql;

public interface Driver {
	
	String getName();
	WorkingSet execute(String command);
	

}
