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

// Not needed when we can implement resetDatabases using DDL operations
import lang::typhonql::Run;
import lang::typhonml::TyphonML;

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
    <"User","address","String">,
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
  
  
  EntityModels models = {<"User", { <"name", "STRING">}, {}>};
  str result = session.read("Inventory", {<"u", "User">}, models); 
  println(result);
  
}  

void smokeTwoBackends1() {
  Request req = (Request)`from User u, Review r select r where r.user == u, u.name == "Pablo"`;
  Session session = executeRequest([req]);
  
  //EntityModels models = schema2entityModels(s);
  EntityModels models = {<"Review", { <"contents", "STRING">}, {}>};
  str result = session.read("Reviews", {<"r", "Review">}, models); 
  println(result);
  
}  

void smokeTwoBackends2() {
  Request req = (Request)`from User u, Biography b select u where u.biography == b, b.text == "Born in Chile"`;
  Session session = executeRequest([req]);
  
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

void smokeInsertMongoAndMaria2() {
	Request req1 = (Request)`insert User { @id: #paul, name: "Paul"}`;
	Request req2 = (Request)`insert Biography { text: "Simple and complex guy" } into #paul.biography`;
	executeRequests([req1, req2]);
}

void smokeInsertIntoCollection() {
	Request req1 = (Request)`insert Product { @id: #pro1, name: "GSM", price: 500}`;
	Request req2 = (Request)`insert Product { @id: #pro2, name: "TV", price: 200}`;
	Request req3 = (Request)`insert User { @id: #paul, name: "Paul"}`;
	Request req4 = (Request)`insert Review { @id: #rev1, contents: "So so", product: #pro1, user: #paul}`;
	Request req5 = (Request)`insert Review { @id: #rev2, contents: "Ok", product: #pro2, user: #paul}`;
	Request req6 = (Request)`update User u where u.@id == #paul set {reviews +: [#rev1, #rev2]}`;
	Request req7 = (Request)`update Product p where p.@id == #pro1 set {reviews +: [#rev1]}`;
	Request req8 = (Request)`update Product p where p.@id == #pro2 set {reviews +: [#rev2]}`;
	
	executeRequests([req1, req2, req3, req4, req5, req6, req7, req8]);
}

// TODO The biography does not get a user field after req2
void smokeWhoOwns1() {
	Request req1 = (Request)`insert Biography { @id: #bio1, text: "Complex guy" }`;
	Request req2 = (Request)`insert User { @id: #paul, name: "Paul", biography: #bio1}`;
	executeRequests([req1, req2]);
}

// TODO Junction table Biography.user-User.biography is empty after req2
void smokeWhoOwns2() {
	Request req1 = (Request)`insert User { @id: #paul, name: "Paul"}`;
	Request req2 = (Request)`insert Biography { @id: #bio1, text: "Complex guy", user: #paul }`;
	executeRequests([req1, req2]);
}

// TODO Junction table Biography.user-User.biography is created after req2, but with the wrong uuid
void smokeWhoOwns3() {
	Request req1 = (Request)`insert User { @id: #paul, name: "Paul"}`;
	Request req2 = (Request)`insert Biography { @id: #bio1,  text: "Complex guy" } into #paul.biography`;
	executeRequests([req1, req2]);
}

// TODO Not performing the cascade delete 
void smokeCrossCascadeDelete1() {
	Request req1 = (Request)`insert User { @id: #paul, name: "Paul"}`;
	Request req2 = (Request)`insert Biography { @id: #bio1, text: "Complex guy", user: #paul }`;
	Request req3 = (Request)`update User u where u.@id == #paul set {biography: #bio1}`;
	Request req4 = (Request)`delete User u where u.@id == #paul`;
	executeRequests([req1, req2, req3, req4]);
	
}

Session executeRequests(list[Request] rs, bool clean = true) {
	if (clean) { 
		resetDatabases();
	} 
	Session session = newSession(connections);
	for (Request r <- rs) {
		Script scr = request2script(r, s);
		iprintln(scr);
		runScript(scr, session, s);
	}
	return session;
}

void resetDatabases() {

	@javaClass{nl.cwi.swat.typhonql.TyphonQL}
	java Model bootConnections(loc polystoreUri, str host, str user, str password);
	
	bootConnections(|http://<HOST>:8080|, HOST, "pablo", "antonio");
	runSchema("http://<HOST>:8080", s);
}
