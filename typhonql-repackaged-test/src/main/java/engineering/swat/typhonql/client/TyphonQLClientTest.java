package engineering.swat.typhonql.client;

import java.io.IOException;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.usethesource.vallang.IMap;
import io.usethesource.vallang.IValue;
import nl.cwi.swat.typhonql.DBType;
import nl.cwi.swat.typhonql.MariaDB;
import nl.cwi.swat.typhonql.MongoDB;
import nl.cwi.swat.typhonql.client.Attribute;
import nl.cwi.swat.typhonql.client.Cardinality;
import nl.cwi.swat.typhonql.client.DatabaseInfo;
import nl.cwi.swat.typhonql.client.Place;
import nl.cwi.swat.typhonql.client.PolystoreConnection;
import nl.cwi.swat.typhonql.client.PolystoreSchema;
import nl.cwi.swat.typhonql.client.Relation;

public class TyphonQLClientTest {
	public static void main(String[] args) throws IOException {
	
		Relation[] rels = new Relation[] {
				new Relation("Order", Cardinality.ZERO_MANY, "products", "orders", Cardinality.ZERO_MANY, "Product",
						false),
				new Relation("Product", Cardinality.ZERO_MANY, "review", "product", Cardinality.ONE, "Review", true),
				new Relation("Product", Cardinality.ZERO_MANY, "orders", "products", Cardinality.ZERO_MANY, "Order",
						false),
				new Relation("Review", Cardinality.ONE, "product", "review", Cardinality.ZERO_MANY, "Product", false),
				new Relation("Comment", Cardinality.ZERO_MANY, "responses", "responses^", Cardinality.ZERO_ONE,
						"Comment", true),
				new Relation("User", Cardinality.ZERO_MANY, "orders", "users", Cardinality.ONE, "Order", false),
				new Relation("Order", Cardinality.ONE, "paidWith", "paidWith^", Cardinality.ZERO_ONE, "CreditCard",
						false),
				new Relation("User", Cardinality.ZERO_MANY, "comments", "comments^", Cardinality.ZERO_ONE, "Comment",
						true),
				new Relation("Order", Cardinality.ONE, "users", "orders", Cardinality.ZERO_MANY, "User", false),
				new Relation("User", Cardinality.ZERO_MANY, "paymentsDetails", "paymentsDetails^", Cardinality.ZERO_ONE,
						"CreditCard", true) };
	
		Attribute[] attrs = new Attribute[] { new Attribute("CreditCard", "expiryDate", "Date"),
				new Attribute("Review", "id", "String"), new Attribute("Comment", "content", "String"),
				new Attribute("Order", "totalAmount", "int"), new Attribute("User", "id", "String"),
				new Attribute("Order", "id", "String"), new Attribute("Product", "id", "String"),
				new Attribute("Product", "name", "String"), new Attribute("Order", "date", "Date"),
				new Attribute("Comment", "id", "String"), new Attribute("Product", "description", "String"),
				new Attribute("User", "name", "String"), new Attribute("CreditCard", "id", "String"),
				new Attribute("CreditCard", "number", "String")
	
		};
	
		Map<Place, List<String>> placement = new HashMap<Place, List<String>>();
	
		placement.put(new Place(DBType.documentdb, "DocumentDatabase"), Arrays.asList("Review", "Comment"));
		placement.put(new Place(DBType.relationaldb, "RelationalDatabase"),
				Arrays.asList("CreditCard", "User", "Order", "Product"));
	
		PolystoreSchema schema = new PolystoreSchema(Arrays.asList(rels), Arrays.asList(attrs), placement);
	
		DatabaseInfo[] infos = new DatabaseInfo[] {
				new DatabaseInfo("localhost", 27017, "DocumentDatabase", DBType.documentdb, new MongoDB().getName(),
						"admin", "admin"),
				new DatabaseInfo("localhost", 3306, "RelationalDatabase", DBType.relationaldb, new MariaDB().getName(),
						"root", "example") };
	
		PolystoreConnection conn = new PolystoreConnection(schema, Arrays.asList(infos), false);
		IValue iv = conn.executeQuery("from User u select u");
		System.out.println(iv);
	
	}
}

