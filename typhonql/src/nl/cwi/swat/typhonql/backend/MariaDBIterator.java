package nl.cwi.swat.typhonql.backend;

import java.sql.ResultSet;
import java.sql.SQLException;

public class MariaDBIterator implements ResultIterator {

	private ResultSet rs;
	private final boolean isEmpty;

	public MariaDBIterator(ResultSet rs) {
		this.rs = rs;
		try {
			this.isEmpty = !rs.isBeforeFirst();
		} catch (SQLException e) {
			throw new RuntimeException(e);
		}
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
			if (isEmpty) {
				return false;
			}
			return !rs.isLast();
		} catch (SQLException e) {
			throw new RuntimeException(e);
		}
	}

	@Override
	public String getCurrentId(String label, String type) {
		try {
			return rs.getString(label + "." + type + ".@id");
		} catch (SQLException e) {
			throw new RuntimeException(e);
		}
	}

	@Override
	public Object getCurrentField(String label, String type, String name) {
		try {
			if (type.startsWith("string") || type.equals("text")) {
				return rs.getString(label + "." + type + "." + name);
			} if (type.startsWith("int") || type.equals("bigint")) {
				return rs.getString(label + "." + type + "." + name);
			} else {
				// TODO rest of the cases!!!
				return rs.getObject(label + "." + type + "." + name);
			}
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
	
	

}
