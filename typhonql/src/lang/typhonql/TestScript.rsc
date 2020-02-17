module lang::typhonql::TestScript

import lang::typhonql::TDBC;
import lang::typhonql::Session;
import lang::typhonql::Script;
import lang::typhonql::Request2Script;
import lang::typhonml::Util;
import lang::typhonml::TyphonML;
import IO;

str HOST = "localhost";

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
  
void smokeSingle() {

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

  Request req = (Request)`from User u, Review r select r where r.user == u, u.name == "Claudio"`;
  
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