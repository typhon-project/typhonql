package nl.cwi.swat.typhonql;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;

import org.rascalmpl.interpreter.utils.RuntimeExceptionFactory;

import io.usethesource.vallang.IInteger;
import io.usethesource.vallang.IList;
import io.usethesource.vallang.IListWriter;
import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IMapWriter;
import io.usethesource.vallang.IString;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory;

public class Bridge {
	
	private final IValueFactory vf;

	public Bridge(IValueFactory vf) {
		this.vf = vf;
	}
	
	
	private static Connection getJDBCConnection(IString dbName) {
		Connection con = (Connection) Connections.getInstance().getConnection(dbName.getValue());
		if (con == null) {
			throw RuntimeExceptionFactory.illegalArgument(dbName, null, null, "No connection for database");
		}
		return con;
	}
	
	
	public IList executeQuery(IString dbName, IString sql) {
		Connection con = getJDBCConnection(dbName);
		try {
			Statement stat = con.createStatement();
			ResultSet rs = stat.executeQuery(sql.getValue());
			IListWriter w = vf.listWriter();
			ResultSetMetaData meta = rs.getMetaData();
			while (rs.next()) {
				IMapWriter record = vf.mapWriter();
				for (int i = 1; i <= meta.getColumnCount(); i++) {
					record.put(vf.string(meta.getColumnName(i)), toValue(rs.getObject(i))); 
				}
				w.append(record.done());
			}
			stat.close();
			return w.done();
		} catch (SQLException e) {
			throw RuntimeExceptionFactory.illegalArgument(sql, null, null, e.getMessage());
		}
	}
	

	public IInteger executeUpdate(IString dbName, IString sql) {
		Connection con = getJDBCConnection(dbName);
		try {
			Statement stat = con.createStatement();
			int result = stat.executeUpdate(sql.getValue());
			return vf.integer(result);
		} catch (SQLException e) {
			throw RuntimeExceptionFactory.illegalArgument(sql, null, null, e.getMessage());
		}
	}
	
	public IMap find(IString dbName, IMap pattern) {
		return vf.map();
	}
	
	public IMap find(IString dbName, IMap pattern, IMap projection) {
		return vf.map();
	}
	
	public IMap findAndModify(IString dbName, IMap pattern, IMap update) {
		return vf.map();
	}
	
	private IValue toValue(Object obj) {
		if (obj instanceof String) {
			return vf.string((String)obj);
		}
		if (obj instanceof Integer) {
			return vf.integer(((Integer)obj).longValue());
		}
		if (obj instanceof Boolean) {
			return vf.bool(((Boolean)obj).booleanValue());
		}
		if (obj instanceof Double) {
			return vf.real(((Double)obj).doubleValue());
		}
		throw RuntimeExceptionFactory.illegalArgument(vf.string(obj.getClass().getName()), null, null, 
				"Cannot convert Java object to Rascal value");
	}

}
