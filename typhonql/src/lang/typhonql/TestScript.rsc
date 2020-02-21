module lang::typhonql::TestScript

import lang::typhonql::TDBC;
import lang::typhonql::Session;
import lang::typhonql::Script;
import lang::typhonql::Request2Script;
import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import IO;
import ParseTree;
import lang::json::\syntax::JSON;

//str HOST = "localhost";

str HOST = "tijs-typhon.duckdns.org";

map[str, Connection] connections = (
			"Reviews" : mongoConnection(HOST, 27018, "admin", "admin"),
 			"Inventory" : sqlConnection(HOST, 3306, "root", "example")
	);
 			
Schema s = schema(
  {
    <"Review",\one(),"product","reviews",zero_many(),"Product",false>,
    <"Review",\one(),"user","reviews",zero_many(),"User",false>,
    <"Biography",\one(),"user","biography",\zero_one(),"User",false>,
    <"Product",zero_many(),"reviews","product",\one(),"Review",true>,
    <"User",zero_many(),"reviews","user",\one(),"Review",true>,
    <"User",zero_one(),"biography","user",\one(),"Biography",true>
  },
  {
    <"User","address","Address">,
    <"Product","price","int">,
    <"Review","contents","String">,
    <"Biography","text","String">,
    <"Product","date","Date">,
    <"Product","name","String">,
    <"Product","description","String">,
    <"User","name","String">
  },
  placement={
    <<mongodb(),"Reviews">,"Review">,
    <<mongodb(),"Reviews">,"Biography">,
    <<sql(),"Inventory">,"User">,
    <<sql(),"Inventory">,"Product">
  },
  elements={
    <"Address","number","int">,
    <"Address","city","String">,
    <"Address","street","String">
  },
  changeOperators=[]);
  

void smokeStat(Request r) {
  println("## Smoking statement:");
  println(r);
  Script scr = request2script(r, s);
  println("## Script:");
  iprintln(scr);
  Session session = newSession(connections);
  runScript(scr, session, s);
}

  
void smokeQuery(Request r, str result, rel[str name, str \type] entities, EntityModels models) {
  println("## Smoking query:");
  println(r);

  Script scr = request2script(r, s);
  
  println("## Script:");
  iprintln(scr);

  Session session = newSession(connections);
  runScript(scr, session, s);
  
  println("## Result:");
  println(session.read(result, entities, models));
  
} 

void smokeSelects() {
  smokeStat((Request)`delete User u where true`);
  smokeStat((Request)`delete Biography b where true`);

  smokeStat((Request)`insert User { @id: #pablo, name: "Pablo" }`);
  smokeStat((Request)`insert User { @id: #davy, name: "Davy" }`);
  smokeStat((Request)`insert User { @id: #tijs, name: "Tijs" }`);

  smokeStat((Request)`insert Biography { text: "Complex guy" } into #tijs.biography`);
  smokeStat((Request)`insert Biography { text: "Simple guy" } into #pablo.biography`);

  smokeQuery((Request)`from User u select u`,"Inventory", {<"u", "User">}, {<"User", { <"@id", "STRING">, <"name", "STRING">}, {}>});
  smokeQuery((Request)`from User u select u.name`,"Inventory", {<"u", "User">}, {<"User", { <"@id", "STRING">, <"name", "STRING">}, {}>});
  smokeQuery((Request)`from User u select u.@id, u.name`,"Inventory", {<"u", "User">}, {<"User", { <"@id", "STRING">, <"name", "STRING">}, {}>});


  smokeQuery((Request)`from User u select u where u.name == "Pablo"`,"Inventory", {<"u", "User">}, {<"User", { <"@id", "STRING">, <"name", "STRING">}, {}>});
  smokeQuery((Request)`from User u select u.name where u.name == "Pablo"`,"Inventory", {<"u", "User">}, {<"User", { <"@id", "STRING">, <"name", "STRING">}, {}>});
  smokeQuery((Request)`from User u select u.@id, u.name where u.name == "Pablo"`,"Inventory", {<"u", "User">}, {<"User", { <"@id", "STRING">, <"name", "STRING">}, {}>});


  smokeQuery((Request)`from User u select u where u.name == "Pablo" || u.name == "Davy"`,"Inventory", {<"u", "User">}, {<"User", { <"@id", "STRING">, <"name", "STRING">}, {}>});
  smokeQuery((Request)`from User u select u.name where u.name == "Pablo" || u.name == "Davy"`,"Inventory", {<"u", "User">}, {<"User", { <"@id", "STRING">, <"name", "STRING">}, {}>});
  smokeQuery((Request)`from User u select u.@id, u.name where u.name == "Pablo"  || u.name == "Davy"`,"Inventory", {<"u", "User">}, {<"User", { <"@id", "STRING">, <"name", "STRING">}, {}>});
  
  smokeQuery((Request)`from Biography b select b`,"Reviews", {<"b", "Biography">}, {<"Biography", { <"@id", "STRING">, <"text", "STRING">}, {}>});
  smokeQuery((Request)`from Biography b select b.text`,"Reviews", {<"b", "Biography">}, {<"Biography", { <"@id", "STRING">, <"text", "STRING">}, {}>});
  smokeQuery((Request)`from Biography b select b.text, b.@id`,"Reviews", {<"b", "Biography">}, {<"Biography", { <"@id", "STRING">, <"text", "STRING">}, {}>});

  smokeQuery((Request)`from Biography b select b where b.user == #pablo `,"Reviews", {<"b", "Biography">}, {<"Biography", { <"@id", "STRING">, <"text", "STRING">}, {}>});

  //smokeQuery((Request)`from User u, Biography b select b where u.biography == #pablo `,"Reviews", {<"b", "Biography">}, {<"Biography", { <"@id", "STRING">, <"text", "STRING">}, {}>});
  //smokeQuery((Request)`from User u, Biography b select u.name, b.text where u.biography == #pablo `,"Reviews", {<"b", "Biography">}, {<"Biography", { <"@id", "STRING">, <"text", "STRING">}, {}>});
  
  
}

void smokeInserts() {
  smokeStat((Request)`delete User u where u.@id == #tijs-id`);
  smokeStat((Request)`insert User { @id: #tijs-id, name: "Tijs" }`);
  smokeStat((Request)`insert Biography { text: "Complex guy" }`);
  smokeStat((Request)`insert Biography { text: "Simple guy" } into #tijs-id.biography`);
}


  
void smokeSingle() {
  smokeQuery((Request)`from User u select u.name where u.name == "Claudio"`,
    "Inventory", {<"u", "User">},
    {<"User", { <"name", "STRING">}, {}>});
    
  return;

  Request req = (Request)`from User u select u.name where u.name == "Claudio"`;
  
  Script scr = request2script(req, s);
  
  Session session = newSession(connections);
  
  iprintln(scr);
  
  runScript(scr, session, s);
  
  //EntityModels models = schema2entityModels(s);
  
  EntityModels models = {<"User", { <"name", "STRING">}, {}>};
  str result = session.read("Inventory", {<"u", "User">}, models); 
  println(result);
  
}  

void smokeTwoBackends1() {

  Request req = (Request)`from User u, Review r select r where r.user == u, u.name == "Pablo"`;
  
  Script scr = request2script(req, s);
	
  Session session = newSession(connections);
  
  iprintln(scr);
  
  runScript(scr, session, s);
  
  //EntityModels models = schema2entityModels(s);
  
  EntityModels models = {<"Review", { <"contents", "STRING">}, {}>};
  str result = session.read("Reviews", {<"r", "Review">}, models); 
  println(result);
  
}  

void smokeTwoBackends2() {

  Request req = (Request)`from User u, Biography b select u where u.biography == b, b.text == "Born in Chile"`;
  
  Script scr = request2script(req, s);
	
  Session session = newSession(connections);
  
  iprintln(scr);
  
  runScript(scr, session, s);
  
  //EntityModels models = schema2entityModels(s);
  
  EntityModels models = {<"User", { <"name", "STRING">}, {}>};
  str result = session.read("Inventory", {<"u", "User">}, models); 
  println(result);
  
}  

void smokeInsertMaria() {
	Session session = newSession(connections);
	Request req1 = (Request)`insert User { name: "Tijs" }`;
	Script scr1 = request2script(req1, s);
	iprintln(scr1);
	runScript(scr1, session, s);
  
}

void smokeInsertMongoAndMaria() {
	Session session = newSession(connections);
	Request req1 = (Request)`insert Biography { text: "Simple guy" }`;
	Script scr1 = request2script(req1, s);
	iprintln(scr1);
	runScript(scr1, session, s);
	
	Request req2 = (Request)`from Biography b select b where b.text == "Simple guy"`;
	Script scr2 = request2script(req2, s);
	iprintln(scr2);
	runScript(scr2, session, s);
	EntityModels models = {<"Biography", { <"text", "STRING">}, {}>};
  	str result = session.read("Reviews", {<"b", "Biography">}, models); 
  	//println(result);
  	JSONText parsed = parse(#JSONText, result);
  	str bioUuid = "";
  	if ((JSONText) `<Object obj>` := parsed) {
  		
  		for ((Member) `<StringLiteral name> : <Value v>` <- obj.members) {
  			if ((Value) `<Array a>` := v) {
  				if ((Value) `<Object obj1>` <- a.values) {
  					if ((Member) `<StringLiteral name1> : <Value v1>` <- obj1.members) {
  						println ("<name1>");
  						if  ("\"uuid\"" == "<name1>") {
  							bioUuid = "<v1>"[1 .. -1];
  						}
  					}
  				}
  			}
  		}
  	}
  	Request req3 = [Request] "insert User {name: \"Tijs\", biography: #<bioUuid>}";
	Script scr3 = request2script(req3, s);
	
  	iprintln(scr3);
  	runScript(scr3, session, s);

}