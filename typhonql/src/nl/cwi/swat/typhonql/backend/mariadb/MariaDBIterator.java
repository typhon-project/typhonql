/********************************************************************************
* Copyright (c) 2018-2020 CWI & Swat.engineering 
*
* This program and the accompanying materials are made available under the
* terms of the Eclipse Public License 2.0 which is available at
* http://www.eclipse.org/legal/epl-2.0.
*
* This Source Code may also be made available under the following Secondary
* Licenses when the conditions for such availability set forth in the Eclipse
* Public License, v. 2.0 are satisfied: GNU General Public License, version 2
* with the GNU Classpath Exception which is
* available at https://www.gnu.org/software/classpath/license.html.
*
* SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0
********************************************************************************/

package nl.cwi.swat.typhonql.backend.mariadb;

import java.io.IOException;
import java.io.InputStream;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Types;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.Calendar;
import java.util.HashMap;
import java.util.Map;
import java.util.TimeZone;
import java.util.UUID;

import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.PrecisionModel;
import org.locationtech.jts.io.InputStreamInStream;
import org.locationtech.jts.io.ParseException;
import org.locationtech.jts.io.WKBReader;
import org.mariadb.jdbc.internal.ColumnType;

import lang.typhonql.util.MakeUUID;
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
	private static final Calendar UTC = Calendar.getInstance(TimeZone.getTimeZone(ZoneId.of("UTC")));

	static {
		columnMapperFuncs = new HashMap<>();
		// TODO: consider not using class name but something else for this mapping (like SQL type)
		columnMapperFuncs.put(ColumnType.BIGINT.getSqlType(), ResultSet::getLong);
		columnMapperFuncs.put(ColumnType.BIT.getSqlType(), ResultSet::getBoolean);
		columnMapperFuncs.put(Types.BINARY, (r, i) -> MakeUUID.uuidFromBytes(r.getBytes(i)));
		columnMapperFuncs.put(ColumnType.LONGBLOB.getSqlType(), (r, i) -> blobOrGeo(r.getBinaryStream(i)));
		columnMapperFuncs.put(ColumnType.DATE.getSqlType(), (r, i) -> r.getDate(i).toLocalDate());
		columnMapperFuncs.put(ColumnType.DATETIME.getSqlType(), (r, i) -> r.getTimestamp(i, UTC).toInstant());
		columnMapperFuncs.put(ColumnType.DOUBLE.getSqlType(), ResultSet::getDouble);
		columnMapperFuncs.put(ColumnType.FLOAT.getSqlType(), ResultSet::getDouble);
		columnMapperFuncs.put(ColumnType.GEOMETRY.getSqlType(), (r, i) -> blobOrGeo(r.getBinaryStream(i)));
		columnMapperFuncs.put(ColumnType.INTEGER.getSqlType(), ResultSet::getInt);
		columnMapperFuncs.put(ColumnType.NULL.getSqlType(), (r, i) -> null);
		columnMapperFuncs.put(ColumnType.STRING.getSqlType(), ResultSet::getString);
		columnMapperFuncs.put(Types.CHAR, ResultSet::getString);
	}
	
	private static Object blobOrGeo(InputStream b) {
		if (b.markSupported()) {
			try {
				b.mark(Integer.MAX_VALUE);
				return new WKBReader(wsgFactory).read(new InputStreamInStream(b));
			} catch (ParseException | IOException e) {
				try {
					b.reset();
				} catch (IOException e1) {
					// should not be possible due to check earlier
				}
				return b;
			}
		}
        System.err.println("Mark not supported so cannot guess blob type");
		return b;
		
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
	public UUID getCurrentId(String label, String type) {
		try {
			return MakeUUID.uuidFromBytes(rs.getBytes(label + "." + type + ".@id"));
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
