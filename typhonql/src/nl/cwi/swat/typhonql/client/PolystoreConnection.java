package nl.cwi.swat.typhonql.client;

import nl.cwi.swat.typhonql.client.resulttable.ResultTable;

public interface PolystoreConnection {

	void resetDatabases();

	ResultTable executeQuery(String query);
	
	void executeDDLUpdate(String update);
	
	CommandResult executeUpdate(String update);
	
	CommandResult[] executePreparedUpdate(String preparedStatement, String[] columnNames,
			String[][] matrix);

}