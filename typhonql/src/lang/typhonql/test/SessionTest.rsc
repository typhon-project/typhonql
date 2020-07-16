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
