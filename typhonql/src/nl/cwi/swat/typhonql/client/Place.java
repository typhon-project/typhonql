package nl.cwi.swat.typhonql.client;

import nl.cwi.swat.typhonql.DBMS;
import nl.cwi.swat.typhonql.DBType;

public class Place {
	private DBType db;
	private String name;
	
	public Place(DBType db, String name) {
		super();
		this.db = db;
		this.name = name;
	}
	
	public DBType getDBType() {
		return db;
	}
	public String getName() {
		return name;
	}
	
}
