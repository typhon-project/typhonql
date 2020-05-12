package nl.cwi.swat.typhonql.backend;

import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.function.Supplier;
import org.locationtech.jts.io.ParseException;
import org.locationtech.jts.io.WKBReader;
import org.mariadb.jdbc.internal.ColumnType;

public class MariaDBIterator implements ResultIterator {

	private final ResultSet rs;
	private final boolean isEmpty;
	private final Map<String, CellSupplier> columnMappers;

	public MariaDBIterator(ResultSet rs) {
		this.rs = rs;
		try {
			this.isEmpty = !rs.isBeforeFirst();
			this.columnMappers = initializeMappers(rs);
		} catch (SQLException e) {
			throw new RuntimeException(e);
		}
	}
	
	@FunctionalInterface
	private interface ColumnMapperFunction {
		Object apply(ResultSet s, int column) throws SQLException;
	}
	
	private static final Map<String, ColumnMapperFunction> columnMapperFuncs;

	static {
		columnMapperFuncs = new HashMap<>();
		// TODO: consider not using class name but something else for this mapping (like SQL type)
		columnMapperFuncs.put(ColumnType.BIGINT.getClassName(), (r, i) -> r.getBigDecimal(i));
		columnMapperFuncs.put(ColumnType.BIT.getClassName(), (r, i) -> r.getBoolean(i));
		columnMapperFuncs.put(ColumnType.BLOB.getClassName(), (r, i) -> r.getBlob(i).getBinaryStream());
		columnMapperFuncs.put(ColumnType.DATE.getClassName(), (r, i) -> r.getObject(i, LocalDate.class));
		columnMapperFuncs.put(ColumnType.DATETIME.getClassName(), (r, i) -> r.getObject(i, LocalDateTime.class));
		columnMapperFuncs.put(ColumnType.DOUBLE.getClassName(), (r, i) -> r.getDouble(i));
		columnMapperFuncs.put(ColumnType.FLOAT.getClassName(), (r, i) -> r.getDouble(i));
		columnMapperFuncs.put(ColumnType.GEOMETRY.getClassName(), (r, i) -> {
			try {
				return new WKBReader().read(r.getBytes(i));
			} catch (ParseException e) {
				// TODO, this class name overlaps with all other things that can give bytes, so we have to map them
				throw new SQLException(e);
			}
		});
		columnMapperFuncs.put(ColumnType.INTEGER.getClassName(), (r, i) -> r.getInt(i));
		columnMapperFuncs.put(ColumnType.NULL.getClassName(), (r, i) -> null);
		columnMapperFuncs.put(ColumnType.STRING.getClassName(), (r, i) -> r.getString(i));
	}
	
	@FunctionalInterface
	private interface CellSupplier {
		Object get() throws SQLException;
		
	}

	private static Map<String, CellSupplier> initializeMappers(ResultSet rs) throws SQLException {
		Map<String, CellSupplier> result = new HashMap<>();
		ResultSetMetaData meta = rs.getMetaData();
		for (int c = 1; c <= meta.getColumnCount(); c++) {
			ColumnMapperFunction func = columnMapperFuncs.get(meta.getColumnClassName(c));
			if (func == null) {
				throw new SQLException("Column "+ meta.getColumnName(c) + " (type: " + meta.getColumnClassName(c) + ") does not have a mapper in QL yet");
			}
			int column = c;
			result.put(meta.getColumnLabel(c), () -> func.apply(rs, column));
			
		}
		return result;

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
			CellSupplier cell = columnMappers.get(label + "." + type + "." + name);
			if (cell == null) {
				throw new RuntimeException("Missing field: " + label +"." + type +"."+ name + " in result");
			}
			return cell.get();
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
