module lang::typhonql::TestScript

import lang::typhonql::TDBC;
import lang::typhonql::Session;
import lang::typhonql::Script;
import lang::typhonql::Request2Script;
import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import IO;

Schema s = schema(
  {
    <"Review",\one(),"product","reviews",zero_many(),"Product",false>,
    <"Review",\one(),"user","reviews",zero_many(),"User",false>,
    <"Product",zero_many(),"reviews","product",\one(),"Review",true>,
    <"User",zero_many(),"reviews","user",\one(),"Review",true>
  },
  {
    <"User","address","Address">,
    <"Product","price","int">,
    <"Review","contents","String">,
    <"Product","date","Date">,
    <"Product","name","String">,
    <"Product","description","String">,
    <"User","name","String">
  },
  placement={
    <<mongodb(),"Reviews">,"Review">,
    <<sql(),"Inventory">,"User">,
    <<sql(),"Inventory">,"Product">
  },
  elements={
    <"Address","number","int">,
    <"Address","city","String">,
    <"Address","street","String">
  },
  changeOperators=[]);
  
void smokeRunSingle() {

  Request req = (Request)`from User u select u.name where u.name == "Pablo"`;
  
  Script scr = request2script(req, s);
  
  map[str, Connection] connections = (
			"Reviews" : mongoConnection("localhost", 27018, "admin", "admin"),
 			"Inventory" : sqlConnection("localhost", 3306, "root", "example")
 	);
 			
  Session session = newSession(connections);
  
  iprintln(scr);
  
  runScript(scr, session, s);
  
  //EntityModels models = schema2entityModels(s);
  
  EntityModels models = {<"User", { <"name", "STRING">}, {}>};
  str result = session.read("Inventory", {<"u", "User">}, models); 
  println(result);
  
}  

void smokeRunTwoBackends() {

  Request req = (Request)`from User u, Review r select r where r.user == u, u.name == "Pablo"`;
  
  Script scr = request2script(req, s);
  
  map[str, Connection] connections = (
			"Reviews" : mongoConnection("localhost", 27018, "admin", "admin"),
 			"Inventory" : sqlConnection("localhost", 3306, "root", "example")
 	);
 			
  Session session = newSession(connections);
  
  iprintln(scr);
  
  runScript(scr, session, s);
  
  //EntityModels models = schema2entityModels(s);
  
  EntityModels models = {<"User", { <"name", "STRING">}, {}>};
  str result = session.read("Inventory", {<"u", "User">}, models); 
  println(result);
  
}  