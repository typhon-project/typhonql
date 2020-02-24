module lang::typhonql::IDE


import lang::typhonml::TyphonML;
import lang::typhonml::Util;
import lang::typhonml::XMIReader;

import lang::typhonql::TDBC;
import lang::typhonql::WorkingSet;
import lang::typhonql::Run;

import util::IDE;
import util::Prompt;
import util::ValueUI;
import ParseTree;
import IO;
import String;
import Message;
import Boolean;

import util::Reflective;
import lang::manifest::IO;


// TODO do the parsing of JSon containing meta information in Rascal
alias ConnectionInfo = tuple[str dbType, str host, int port, str dbName, str user, str password];

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java void bootConnections(loc polystoreUri, str user, str password);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java str readHttpModel(loc polystoreUri, str user, str password);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java void executeResetDatabases(loc polystoreUri, str user, str password);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java WorkingSet executeQuery(loc polystoreUri, str user, str password, str query);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java void executeUpdate(loc polystoreUri, str user, str password, str query);

private str TYPHONQL = "TyphonQL";

data TyphonQLManifest 
 = typhonQLManifest(
      str PolystoreHost = "localhost",
      str PolystorePort = "8080",
      str PolystoreUser = "",
      str PolystorePassword = ""
    );        
 
private loc configFile(loc file) =  project(file) + "META-INF" + "RASCAL.MF"; 

private loc project(loc file) {
   assert file.scheme == "project";
   return |project:///|[authority = file.authority];
}


PathConfig getDefaultPathConfig() = pathConfig();

TyphonQLManifest readTyphonConfig(loc file) {
   assert file.scheme == "project";

   p = project(file);
   cfgFile = configFile(file);
   mf = readManifest(#TyphonQLManifest, cfgFile);
   
   return mf;
}

loc buildPolystoreUri(loc projectLoc) {
	TyphonQLManifest typhonConf = readTyphonConfig(projectLoc);
	return |http://<typhonConf.PolystoreHost>:<typhonConf.PolystorePort>|;
}

Schema checkSchema(Schema sch, loc projectLoc) {
	if (schema({}, {}) := sch) {
		loc polystoreUri = buildPolystoreUri(projectLoc);
		TyphonQLManifest typhonConf = readTyphonConfig(projectLoc);
		str user = typhonConf.PolystoreUser;
		str password = typhonConf.PolystorePassword;
		str modelStr = readHttpModel(polystoreUri, user, password);
		Schema newSch = loadSchemaFromXMI(modelStr);
		
		set[Message] msgs = schemaSanity(newSch, projectLoc);
	    if (msgs != {}) {
	      throw "Not all entities assigned to backend in the model in polystore. Please upload a consistent model before continuing.";
	    }
		
		bootConnections(polystoreUri, user, password);
		sch = newSch;
	}
	
    return sch;
	
	/*
		}
		else {
			loc modelLoc = |project://typhonql/src/lang/typhonml/mydb4.xmi|;
			Schema sch = loadSchema(modelLoc);
			return sch;
		}
	*/
		
	/*} catch value v:{
		println(v);
		return schema({}, {});
	}*/
}

void setupIDE(bool isDevMode = false) {
  Schema sch = schema({}, {});
  
  registerLanguage(TYPHONQL, "tql", start[Script](str src, loc org) {
    return parse(#start[Script], src, org);
  });
  
  //// fake it for now.
  //Model schema = load(#Model, |project://typhonql/src/lang/typhonml/mydb4.xmi|); 

  // call this in the parse handler or from a menu to avoid race conditions
  // with the rest of the platform.
  //Model m = bootTyphonQL(#Model, |tmp:///|);
  
  //iprintln(m);
  // todo: assert loaded on all actions (now an initial save is needed)
  
  actions = [
      action("Execute",  void (Tree tree, loc selection) {
        if (treeFound(Request req) := treeAt(#Request, selection, tree)) {
        	loc polystoreUri = buildPolystoreUri(tree@\loc);
        	if (isDevMode) {
	          try {
	          	sch = checkSchema(sch, tree@\loc);
	      	  	value result = run(req, polystoreUri.uri, sch);
	          	if (WorkingSet ws := result) {
	            	text(ws);
	          	}
	          	else {
	            	alert("Operation succesfully executed");
	          	}
	          } catch e: {
        		alert("Error: <e> ");
          	  }
          	} else {
          	  // not dev mode
          	  try {
          		sch = checkSchema(sch, tree@\loc);
          		TyphonQLManifest typhonConf = readTyphonConfig(tree@\loc);
          		str user = typhonConf.PolystoreUser;
				str password = typhonConf.PolystorePassword;
          		if (req is query) {
	      	  		WorkingSet ws = executeQuery(polystoreUri, user, password, "<req>");
	          		text(ws);
	          	}
	          	else {
	          	    executeUpdate(polystoreUri, user, password, "<req>");
	            	alert("Operation succesfully executed");
	          	}
	          } catch e: {
        		alert("Error: <e> ");
          	  }
          		
          	}
       }   
      }),
      action("Reload schema from polystore",  void (Tree tree, loc selection) {
      	try {
        	sch = schema({}, {});
        	sch = checkSchema(sch, tree@\loc);
        	alert("Schema successfully reloaded from polystore");
        } catch e: {
        	alert("Error: <e> ");
        }  
      }),
      action("Dump schema",  void (Tree tree, loc selection) {
      	try {
      		sch = checkSchema(sch, tree@\loc);
        	dumpSchema(sch);
        	text(sch);
        } catch e: {
        	alert("Error: <e> ");
        } 
      }),
      action("Reset database...", void (Tree tree, loc selection) {
      	str yes = prompt("Are you sure to reset the polystore? (type \'yes\' to confirm)");
      	if (yes == "yes") {
      		loc polystoreUri = buildPolystoreUri(tree@\loc);
        	if (isDevMode) {        		
        		try {
          			sch = checkSchema(sch, tree@\loc);
          			runSchema(polystoreUri.uri, sch);
          			alert("Polystore successfully reset");
          		} catch e: {
	        		alert("Error: <e> ");
    	    	}
    	    } else {
    	    	// non dev mode 
          		TyphonQLManifest typhonConf = readTyphonConfig(tree@\loc);
    	    	str user = typhonConf.PolystoreUser;
				str password = typhonConf.PolystorePassword;
          		executeResetDatabases(polystoreUri, user, password);
	          	alert("Polystore successfully reset");
    	    }
    	      
        }
      })
      
    ];
  
  if (isDevMode) {
  	actions += action("Dump database",  void (Tree tree, loc selection) {
      	try {
      		sch = checkSchema(sch, tree@\loc);
      		loc polystoreUri = buildPolystoreUri(tree@\loc);
      		text(dumpDB(polystoreUri.uri, sch));
      	} catch e: {
        	alert("Error: <e> ");
        } 
      });
      
  }
  
  registerContributions(TYPHONQL, {
    builder(set[Message] (start[Script] s) {
      //try {
      	//Model m = bootTyphonQL(#Model, |tmp:///|);
      	//loc polystoreUri = buildPolystoreUri(tree@\loc);
      	//bootConnections(polystoreUri, typhonConf.PolystoreUser, typhonConf.PolystorePassword);
        //sch = getSchema(polystoreUri, typhonConf.PolystoreUser, typhonConf.PolystorePassword);
      /*}
      catch value v: {
        return {error("Error loading schema: <v>", s@\loc)};
      }*/
      return {};
    }),
    outliner(scriptOutliner),
    popup(menu("TyphonQL", actions))
  }); 
  
  
}

node scriptOutliner(start[Script] script) {
   sections = [];
   inserts = [];
   updates = [];
   selects = [];
   deletes = [];
   
   for (Request req <- script.top.scratch.requests) {
     node x = "req"()[@label="<req>"][@\loc=req@\loc];
     if (req is query) {
       selects += [x];
     }
     else if ((Request)`<Statement s>` := req) {
       if (s is update) {
         updates += [x];
       }
       if (s is \insert) {
         inserts += [x];
       }
       if (s is delete) {
         deletes += [x];
       }
     }
   }
   sections = [
     ""([
       ""(selects)[@label="Selects"],
       ""(inserts)[@label="Inserts"],
       ""(updates)[@label="Updates"],
       ""(deletes)[@label="Deletes"]
     ])[@label="Requests"]
   ];
   return "outline"([sections])[@label="Script"];
    
}

void main(bool isDevMode = false) {
  setupIDE(isDevMode = isDevMode);
}

