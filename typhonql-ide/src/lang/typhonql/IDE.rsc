module lang::typhonql::IDE


import lang::typhonml::TyphonML;
import lang::typhonml::Util;
import lang::typhonml::XMIReader;

import lang::typhonql::TDBC;
import lang::typhonql::DDL;
import lang::typhonql::RunUsingCompiler;

import lang::typhonql::check::Checker;

import lang::typhonql::Session;
import lang::typhonql::Script;
import lang::typhonql::Request2Script;


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

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java map[str, Connection] readConnectionsInfo(loc uri, str user, str password);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java str readHttpModel(loc polystoreUri, str user, str password);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java bool executeResetDatabases(loc polystoreUri, str user, str password);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java ResultTable executeQuery(loc polystoreUri, str user, str password, str query);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java void executeDDLUpdate(loc polystoreUri, str user, str password, str query);

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
 
private loc configFile(loc file) =  project(file) + "META-INF/RASCAL.MF"; 

private loc project(loc file) {
   assert file.scheme == "project";
   return |project:///|[authority = file.authority];
}


PathConfig getDefaultPathConfig() = pathConfig();

alias PolystoreInfo = tuple[loc uri, str user, str password];

PolystoreInfo readTyphonConfig(loc file) {
   assert file.scheme == "project";

   p = project(file);
   cfgFile = configFile(file);
   typhonConf = readManifest(#TyphonQLManifest, cfgFile);
   
   return <|http://<typhonConf.PolystoreHost>:<typhonConf.PolystorePort>|,
   	typhonConf.PolystoreUser, typhonConf.PolystorePassword>; 
}

Schema getSchema(loc polystoreUri, str user, str password) {
    str modelStr = readHttpModel(polystoreUri, user, password);
    Schema newSch = loadSchemaFromXMI(modelStr);
    
    set[Message] msgs = schemaSanity(newSch, polystoreUri);
    if (msgs != {}) {
      throw "Not all entities assigned to backend in the model in polystore. Please upload a consistent model before continuing.";
    }
    return newSch;
}

Tree checkQL(Tree input, CheckerMLSchema sch){
    model = checkQLTree(input, sch);
    types = getFacts(model);
  
  return input[@messages={*getMessages(model)}]
              [@hyperlinks=getUseDef(model)]
              [@docs=(l:"<prettyAType(types[l])>" | l <- types)]
         ; 
}

map[str, Connection] getConnections(Tree tree) {
  <polystoreUri, user, password> = readTyphonConfig(tree@\loc);
  return readConnectionsInfo(polystoreUri, user, password);
}

Session getSession(Tree tree) {
  map[str, Connection] connections =  getConnections(tree);
  return newSession(connections);
}

void setupIDE(bool isDevMode = false) {
  Schema sch = schema({}, {});
  CheckerMLSchema cSch = ();
  
  Schema currentSchema(Tree tree) {
	if (schema({}, {}) := sch) {
        <polystoreUri, user, password> = readTyphonConfig(tree@\loc);
        sch = getSchema(polystoreUri, user, password);
        cSch = convertModel(sch);
    }
    return sch;
  }
  
  CheckerMLSchema currentCheckerSchema(Tree tree) {
    if (cSch == ()) {
        currentSchema(tree);
    }
    return cSch;
  }
  
  
  
  void resetSchema() {
    sch = schema({}, {});
    cSch = ();
  }
  
  
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
        	if (isDevMode) {
	          try {
	          	if ((Request) `<Query q>` := req) {
	          		ResultTable result = runQuery(req, currentSchema(tree), getSession(tree));
	            	text(result);
	          	}
	          	else if ((Request) `<Statement s>` := req)  {
	          		if (isDDL(s)) {
	          			// use interpreter
	          			 runDDL(req, currentSchema(tree), getSession(tree));
	          		}
	          		else {
	          			// use compiler
	          			runUpdate(req, currentSchema(tree), getSession(tree));
	          		}
	            	alert("Operation succesfully executed");
	          	}
	          } catch e: {
        		alert("Error: <e> ");
          	  }
          	} else {
          	  // not dev mode
          	  try {
          		if ((Request) `<Query q>` := req) {
                    <polystoreUri, user, password> = readTyphonConfig(tree@\loc);
	      	  		ResultTable ws = executeQuery(polystoreUri, user, password, "<req>");
	          		text(ws);
	          	}
	          	else if ((Request) `<Statement s>` := req)  {
	          		if (isDDL(s)) {
	          			executeDDLUpdate(polystoreUri, user, password, "<req>");
	          		}
	          		else {
	          	    	executeUpdate(polystoreUri, user, password, "<req>");
	          	    }
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
      	     resetSchema();
      	     currentSchema(tree);
        	 alert("Schema successfully reloaded from polystore");
        } catch e: {
        	alert("Error: <e> ");
        }  
      }),
      action("Dump schema",  void (Tree tree, loc selection) {
      	try {
        	println(ppSchema(currentSchema(tree)));
        	text(sch);
        } catch e: {
        	alert("Error: <e> ");
        } 
      }),
      action("Reset database...", void (Tree tree, loc selection) {
      	str yes = prompt("Are you sure to reset the polystore? (type \'yes\' to confirm)");
      	if (yes == "yes") {
      		if (isDevMode) {        		
        		try {
          			runSchema(currentSchema(tree), getSession(tree));
          			alert("Polystore successfully reset");
          		} catch e: {
	        		alert("Error: <e> ");
    	    	}
    	    } else {
    	    	// non dev mode 
    	    	try {
              		<polystoreUri, user, password> = readTyphonConfig(tree@\loc);
           			bool isReset = executeResetDatabases(polystoreUri, user, password);
           			if (isReset)
           				alert("Polystore successfully reset");
           			else
           				alert("Problem with the polystore: Polystore could not be reset");
           		} catch e: {
	        		alert("Error: <e> ");
    	    	}	
    	    }
    	      
        }
      })
      
    ];
    
  /*
  if (isDevMode) {
  	actions += action("Dump database",  void (Tree tree, loc selection) {
  		try {
      		text(dumpDB(currentSchema(tree), getConnections(tree)));
      	} catch e: {
        	alert("Error: <e> ");
        } 
      });
      
  }
  */
  
  registerContributions(TYPHONQL, {
    outliner(scriptOutliner),
    popup(menu("TyphonQL", actions)),
    annotator(Tree (Tree inp) {
        return checkQL(inp, currentCheckerSchema(inp));
    })
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

