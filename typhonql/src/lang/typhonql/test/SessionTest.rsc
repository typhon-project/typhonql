module lang::typhonql::\test::SessionTest

 import lang::typhonql::Session;
 import IO;
 
 void main() {
 	rel[str, str, str, int, str, str] dbs = {
			<"Reviews", "MongoDB", "localhost", 27018, "admin", "admin">,
 			<"Inventory", "MariaDB", "localhost", 3306, "root", "example">
 	};
 			
 	Session session = newSession();
 	 	
 	session.sql.executeQuery("user", "localhost", 3306, "root", "example", "Inventory", "select * from User where `User.name` = \"Claudio\"", ());
 	session.mongo.find("review", "localhost", 27018, "admin", "admin", "Reviews", "Review\n{ user: \"${user_id}\" }", ("user_id" : <"user", "User", "@id">));
 	session.sql.executeQuery("result", "localhost", 3306, "root", "example", "Inventory", "select `Product.@id` as p_id, Product.* from Product where `Product.@id` = ?",
 		("product_id" : <"review", "Review", "product">));
 	
 	//str (str result, rel[str name, str \type] entities, EntityModels models) read,
 	//alias EntityModels = rel[str name, rel[str name, str \type] attributes, rel[str name, str entity] relations];

 	EntityModels models = {<"Product", { <"description", "STRING">, <"name", "STRING">}, {}>};
 	str result = session.read("result", {<"product", "Product">}, models);
 	
 	println(result);
}