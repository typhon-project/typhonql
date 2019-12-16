module lang::typhonql::\test::SessionTest

 import lang::typhonql::Session;
 import IO;
 
 void main() {
 	rel[str, str, str, int, str, str] dbs = 
 		   {
 		    <"Reviews", "MongoDB", "localhost", 27018, "admin", "admin">,
 			<"Inventory", "MariaDB", "localhost", 3306, "root", "example"> };
 	Session session = newSession(dbs);
 	 	
 	session.executeQuery("user", "Inventory", "select * from User where `User.name` = \"Pablo\"", ());
 	session.executeQuery("review", "Reviews", "Review\n{ user: \"${user_id}\" }", ("user_id" : <"user", "User", "@id">));
 	session.executeQuery("result", "Inventory", "select `Product.@id` as p_id, Product.* from Product where `Product.@id` = \"${product_id}\"", ("product_id" : <"review", "Review", "product">));
 	
 	//str (str result, rel[str name, str \type] entities, EntityModels models) read,
 	//alias EntityModels = rel[str name, rel[str name, str \type] attributes, rel[str name, str entity] relations];
 	
 	EntityModels models = {<"Product", { <"description", "STRING">, <"name", "STRING">}, {}>};
 	
 	str result = session.read("result", {<"product", "Product">}, models);
 	
 	println(result);
 }