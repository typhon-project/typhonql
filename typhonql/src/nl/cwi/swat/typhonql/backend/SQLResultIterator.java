package nl.cwi.swat.typhonql.backend;

import java.sql.ResultSet;
import java.sql.SQLException;

public class SQLResultIterator implements ResultIterator {

	private String type;
	private ResultSet rs;

	public SQLResultIterator(String type, ResultSet rs) {
		this.type = type;
		this.rs = rs;
	}

	@Override
	public void nextResult() {
		try {
			rs.next();
		} catch (SQLException e) {
			throw new RuntimeException(e);
		}

	}

	@Override
	public boolean hasNextResult() {
		try {
			return !rs.isLast();
		} catch (SQLException e) {
			throw new RuntimeException(e);
		}
	}

	@Override
	public String getCurrentId() {
		try {
			return rs.getString(type + ".@id");
		} catch (SQLException e) {
			throw new RuntimeException(e);
		}
	}

	@Override
	public Object getCurrentField(String name) {
		try {
			return rs.getObject(type + "." + name);
		} catch (SQLException e) {
			throw new RuntimeException(e);
		}
	}

	@Override
	public void beforeFirst() {
		try {
			rs.beforeFirst();
		} catch (SQLException e) {
			throw new RuntimeException(e);
		}
	}

	@Override
	public String getType() {
		// TODO Auto-generated method stub
		return type;
	}

}
