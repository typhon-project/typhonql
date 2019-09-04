module lang::typhonql::relational::JDBC


data ConnectionMethod
  = createStatement() // returns Statement
  | createPreparedStatement(str sql); // returns PreparedStatement


data StatementMethod
  = executeQuery(str sql) // returns ResultSet
  | executeUpdate(str sql) // returns int
  ;