package nl.cwi.swat.typhonql.client;

import nl.cwi.swat.typhonql.DBMS;

public class Place {
	private DBMS db;
	private String name;
	
	public Place(DBMS db, String name) {
		super();
		this.db = db;
		this.name = name;
	}
	
	public DBMS getDBType() {
		return db;
	}
	public String getName() {
		return name;
	}
	
}
