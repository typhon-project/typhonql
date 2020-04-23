package nl.cwi.swat.typhonql.backend;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.Map;

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
	public String getCurrentField(String label, String type, String name) {
		try {
			Object fromDB = rs.getObject(label + "." + type + "." + name);
			return toGenericString(fromDB);
		} catch (SQLException e) {
			throw new RuntimeException(e);
		}
	}

	private String toGenericString(Object fromDB) {
		if (fromDB == null)
			return "null";
		// Here how to convert SQL objects into neutral typhon strings
		// TODO for now only calling toString
		return fromDB.toString();
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
