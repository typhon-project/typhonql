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

package nl.cwi.swat.typhonql.client.resulttable;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.math.BigInteger;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Collections;
import java.util.List;

import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.Polygon;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializerProvider;
import com.fasterxml.jackson.databind.module.SimpleModule;
import com.fasterxml.jackson.databind.ser.std.StdSerializer;

import io.usethesource.vallang.IExternalValue;
import io.usethesource.vallang.type.Type;
import nl.cwi.swat.typhonql.client.JsonSerializableResult;


public class ResultTable implements JsonSerializableResult, IExternalValue {


				
	private final List<String> columnNames;
	private final List<List<Object>> values;
	
	public ResultTable(List<String> columnNames, List<List<Object>> values) {
		this.columnNames = columnNames;
		this.values = values;
	}
	
	public ResultTable() {
		this(Collections.emptyList(), Collections.emptyList());
	}

	public List<String> getColumnNames() {
		return columnNames;
	}

	public List<List<Object>> getValues() {
		return values;
	}
	
	@JsonIgnore
	public boolean isEmpty() {
		return values == null || values.size() == 0;
	}
	
	@JsonIgnore
	public void serializeJSON(OutputStream target) throws IOException {
		QLSerialization.mapper.writeValue(target, this);
	}
	
	
	
	@Override
	public String toString() {
		return "ResultTable [\ncolumnNames=" + columnNames + ",\n values=" + values + "\n]";
	}
	
	@Override
	@JsonIgnore
	public Type getType() {
		return TF.externalType(TF.valueType());
	}
	
	@Override
	@JsonIgnore
	public boolean isAnnotatable() {
        return false;
    }

	public static String serializeAsString(Object object) {
		// TODO complete all the cases
		if (object == null)
			return "null";
		if (object instanceof String)
			return "\"" + object + "\"";
		else if (object instanceof Integer || object instanceof BigInteger)
			return object.toString();
		else
			return object.toString();
		
	}
	

}
