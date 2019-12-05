package engineering.swat.typhonql.client.dummy;

import java.util.Arrays;
import java.util.stream.Collectors;

import io.usethesource.vallang.IMapWriter;
import io.usethesource.vallang.IValueFactory;
import io.usethesource.vallang.impl.persistent.ValueFactory;
import nl.cwi.swat.typhonql.Bridge;
import nl.cwi.swat.typhonql.ConnectionInfo;
import nl.cwi.swat.typhonql.Connections;
import nl.cwi.swat.typhonql.DBType;
import nl.cwi.swat.typhonql.MariaDB;
import nl.cwi.swat.typhonql.MongoDB;
import nl.cwi.swat.typhonql.client.DatabaseInfo;

public class DropMongoAttribute {
	public static void main(String[] args) {
		DatabaseInfo[] infos = new DatabaseInfo[] {
				new DatabaseInfo("localhost", 27018, "Reviews", DBType.documentdb, new MongoDB().getName(), "admin",
						"admin"),
				new DatabaseInfo("localhost", 3306, "Inventory", DBType.relationaldb, new MariaDB().getName(), "root",
						"example") };
		Connections.boot(Arrays.asList(infos).stream().map(i -> new ConnectionInfo("localhost", i))
				.collect(Collectors.toList()).toArray(new ConnectionInfo[0]));
		IValueFactory vf = ValueFactory.getInstance();
		
		IMapWriter mw0 = vf.mapWriter();
		
		mw0.put(vf.string("contents"), vf.integer(1));
		
		IMapWriter mw = vf.mapWriter();
		
		mw.put(vf.string("$unset"), mw0.done());
		
		new Bridge(vf).updateMany(vf.string("localhost"), vf.string("Reviews"), vf.string("Review"), vf.map(), mw.done());
	}
}
