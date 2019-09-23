package nl.cwi.swat.typhonql;

public enum DBType {
	relationaldb() {
		@Override 
		DBMS[] getPossibleDBMSs() { return new DBMS[] { new MariaDB(), new MySQL() }; }
	},
	
	documentdb() {
		@Override 
		DBMS[] getPossibleDBMSs() { return new DBMS[] { new MongoDB() }; }
		
	};

	abstract DBMS[] getPossibleDBMSs();
	DBMS getDBMS(String dbName) {
		for (DBMS db : getPossibleDBMSs()) {
			if (db.getName().equalsIgnoreCase(dbName))
				return db;
		}
		throw new RuntimeException("Database " + dbName + " not found");
	}
}
