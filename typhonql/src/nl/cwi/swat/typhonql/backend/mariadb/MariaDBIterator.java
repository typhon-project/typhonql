package nl.cwi.swat.typhonql.backend.mariadb;

import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.PrecisionModel;
import org.locationtech.jts.io.ParseException;
import org.locationtech.jts.io.WKBReader;
import org.mariadb.jdbc.internal.ColumnType;

import nl.cwi.swat.typhonql.backend.ResultIterator;

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
	
	private static final Map<Integer, ColumnMapperFunction> columnMapperFuncs;
	private static final GeometryFactory wsgFactory = new GeometryFactory(new PrecisionModel(), 4326);

	static {
		columnMapperFuncs = new HashMap<>();
		// TODO: consider not using class name but something else for this mapping (like SQL type)
		columnMapperFuncs.put(ColumnType.BIGINT.getSqlType(), (r, i) -> r.getBigDecimal(i));
		columnMapperFuncs.put(ColumnType.BIT.getSqlType(), (r, i) -> r.getBoolean(i));
		columnMapperFuncs.put(ColumnType.LONGBLOB.getSqlType(), (r, i) -> r.getBlob(i).getBinaryStream());
		columnMapperFuncs.put(ColumnType.DATE.getSqlType(), (r, i) -> r.getObject(i, LocalDate.class));
		columnMapperFuncs.put(ColumnType.DATETIME.getSqlType(), (r, i) -> r.getObject(i, LocalDateTime.class));
		columnMapperFuncs.put(ColumnType.DOUBLE.getSqlType(), (r, i) -> r.getDouble(i));
		columnMapperFuncs.put(ColumnType.FLOAT.getSqlType(), (r, i) -> r.getDouble(i));
		columnMapperFuncs.put(ColumnType.GEOMETRY.getSqlType(), (r, i) -> {
			try {
				return new WKBReader(wsgFactory).read(r.getBytes(i));
			} catch (ParseException e) {

				// TODO, this class name overlaps with all other things that can give bytes, so we have to map them
				throw new SQLException(e);
			}
		});
		columnMapperFuncs.put(ColumnType.INTEGER.getSqlType(), (r, i) -> r.getInt(i));
		columnMapperFuncs.put(ColumnType.NULL.getSqlType(), (r, i) -> null);
		columnMapperFuncs.put(ColumnType.STRING.getSqlType(), (r, i) -> r.getString(i));
	}
	
	@FunctionalInterface
	private interface CellSupplier {
		Object get() throws SQLException;
		
	}

	private static Map<String, CellSupplier> initializeMappers(ResultSet rs) throws SQLException {
		Map<String, CellSupplier> result = new HashMap<>();
		ResultSetMetaData meta = rs.getMetaData();
		for (int c = 1; c <= meta.getColumnCount(); c++) {
			ColumnMapperFunction func = columnMapperFuncs.get(meta.getColumnType(c));
			if (func == null) {
				throw new SQLException("Column "+ meta.getColumnName(c) + " (type: " + meta.getColumnType(c) + ") does not have a mapper in QL yet");
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
