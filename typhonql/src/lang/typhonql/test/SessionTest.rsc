module lang::typhonql::\test::SessionTest

 import lang::typhonql::Session;
 import IO;
 
 void main() {
 	map[str, Connection] connections = (
			"Reviews" : mongoConnection("localhost", 27018, "admin", "admin"),
 			"Inventory" : mariaConnection("localhost", 3306, "root", "example")
 	);
 			
 	Session session = newSession(connections);
 	 	
 	session.sql.executeQuery("user", "Inventory",
 		"select u.`User.@id` as `u.User.@id`,  u.`User.name` as `u.User.name` from User u where u.`User.name` = \"Claudio\"", ());
 	session.mongo.find("review", "Reviews", "Review", "{ user: \"${user_id}\" }", ("user_id" : <"user", "u", "User", "@id">));
 	session.sql.executeQuery("result", "Inventory", "select p.`Product.@id` as `p.Product.@id`, p.`Product.name` as `p.Product.name`, p.`Product.description` as `p.Product.description` from Product p where p.`Product.@id` = ?",
 		("product_id" : <"review", "dummy", "Review", "product">));
 	
 	//str (str result, rel[str name, str \type] entities, EntityModels models) read,
 	//alias EntityModels = rel[str name, rel[str name, str \type] attributes, rel[str name, str entity] relations];

 	EntityModels models = {<"Product", { <"description", "STRING">, <"name", "STRING">}, {}>};
 	str result = session.read("result", {<"product", "Product">}, models);
 	
 	println(result);
}