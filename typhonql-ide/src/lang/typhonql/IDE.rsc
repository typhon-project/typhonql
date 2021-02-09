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

module lang::typhonql::IDE


import lang::typhonml::TyphonML;
import lang::typhonml::Util;
import lang::typhonml::XMIReader;

import lang::typhonql::TDBC;
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
import lang::json::IO;
import lang::manifest::IO;

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java map[str, Connection] readConnectionsInfo(loc uri, str user, str password);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java str readHttpModel(loc polystoreUri, str user, str password);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java bool executeResetDatabases(loc polystoreUri, str user, str password);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java str executeQuery(loc polystoreUri, str user, str password, str query);

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
 
private loc configFile(loc file) {
    p = project(file);
    return firstExisting([
        (file.parent).top + "typhon.mf",
        p + "typhon.mf",
        p + "src/typhon.mf",
        p + "META-INF/typhon.mf",
        p + "META-INF/TYPHON.MF",
        p + "META-INF/RASCAL.MF"
    ]);
}

private loc firstExisting(list[loc] candidates) {
    for (c <- candidates, exists(c)) {
        return c;
    }
    throw "Cannot find typhon.mf file, tried: <candidates>";
}

private loc project(loc file) {
   assert file.scheme == "project";
   return |project:///|[authority = file.authority];
}


PathConfig getDefaultPathConfig() = pathConfig();

alias PolystoreInfo = tuple[loc uri, str user, str password];

PolystoreInfo readTyphonConfig(loc file) {
   cfgFile = configFile(file);
   typhonConf = readManifest(#TyphonQLManifest, cfgFile);
   println("<cfgFile> : <typhonConf>");
   
   return <|http://<typhonConf.PolystoreHost>:<typhonConf.PolystorePort>|,
   	typhonConf.PolystoreUser, typhonConf.PolystorePassword>; 
}

tuple[Schema, Schema] getSchema(loc polystoreUri, str user, str password) {
    str modelStr = readHttpModel(polystoreUri, user, password);
    Schema newSch = loadSchemaFromXMI(modelStr, normalize = true);
    Schema plainSch = loadSchemaFromXMI(modelStr, normalize = false);
    
    set[Message] msgs = schemaSanity(newSch, polystoreUri);
    if (msgs != {}) {
      println(msgs);
      throw "Not all entities assigned to backend in the model in polystore. Please upload a consistent model before continuing.";
    }
    return <newSch, plainSch>;
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

bool inside(loc full, loc selection) 
    = full.offset <= selection.offset && (full.offset + full.length) >= selection.offset;

TreeSearchResult[Request] findRequest(start[Script] fullTree, loc selection) {
    for (r <- fullTree.top.scratch.requests, inside(r@\loc, selection)) {
        return treeFound(r); 
    }
    return treeNotFound();
}
default TreeSearchResult[Request] findRequest(_,_) = treeNotFound();

data TableResultJSON = contents(list[str] columnNames, list[list[value]] values);

bool isNumber(int _) = true;
bool isNumber(real _) = true;
bool isNumber(num _) = true;
default bool isNumber(value _) = false;

int max(int a, int b) = a > b ? a : b;

list[list[str]] printTable(list[str] columnNames, list[list[value]] values ) {
    colWidth = [ ( size(columnNames[i]) | max(it, size("<v[i]>")) | v <- values) | i <- [0..size(columnNames)]];
    result = [];
    line = "";
    for (i <- [0..size(columnNames)]) {
        if (i > 0) {
            line += " | ";
        }
        line += left(columnNames[i], colWidth[i]);
    }
    result += [[line]];

    line = "";
    bool first = true;
    for (c <- colWidth) {
        if (first) {
            first = false;
        }
        else {
            line += "-|-";
        }
        line += ("" | it + "-" | i <- [0..c]);
    }
    result += [[line]];

    for (vs <- values) {
        line = "";
        for (i <- [0..size(vs)]) {
            if (i > 0) {
                line += " | ";
            }
            line += isNumber(vs[i]) ? right(vs[i], colWidth[i]) : left(vs[i], colWidth[i]);
        }
        result += [[line]];
    }
    return result;
}

void setupIDE(bool isDevMode = false) {
  Schema sch = schema({}, {}, {});
  CheckerMLSchema cSch = <(), {}>;
  
  Schema currentSchema(Tree tree) {
	if (schema({}, {}, {}) := sch) {
        <polystoreUri, user, password> = readTyphonConfig(tree@\loc);
        <sch, plainSch> = getSchema(polystoreUri, user, password);
        cSch = convertModel(plainSch);
    }
    return sch;
  }
  
  CheckerMLSchema currentCheckerSchema(Tree tree) {
    if (cSch == <(), {}>) {
        currentSchema(tree);
    }
    return cSch;
  }
  
  
  
  void resetSchema() {
    sch = schema({}, {}, {});
    cSch = <(), {}>;
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
      	if (treeFound(Tree req) := findRequest(tree, selection)) {
        	if (isDevMode) {
	          try {
	          	if ((Request) `<Query q>` := req) {
	          		ResultTable result = runQuery(req, currentSchema(tree), getSession(tree));
	            	text(printTable(result.columnNames, result.values));
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

	          		result = parseJSON(#TableResultJSON, "{\"contents\": <executeQuery(polystoreUri, user, password, "<req>")> }");
	            	text(printTable(result.columnNames, result.values));
	          	}
	          	else if ((Request) `<Statement s>` := req)  {
                    <polystoreUri, user, password> = readTyphonConfig(tree@\loc);
	          		if (isDDL(s)) {
	          			executeDDLUpdate(polystoreUri, user, password, "<req>");
	          		}
	          		else {
	          	    	executeUpdate(polystoreUri, user, password, "<req>");
	          	    }
	            	alert("Operation succesfully executed");
	          	}
	          	else {
	          	    println("Could not match: <#Statement>");
	          	
	          	}
	          } catch e: {
        		alert("Error: <e> ");
          	  }
          		
          	}
       }   
       else {
        alert("Error: no query selected: <selection>");
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
  list[CompletionProposal] completer(&T<:Tree input, str prefix, int requestOffset) {
      if (treeFound(Tree req) := findRequest(input, |ignored:///|[offset=requestOffset][length=1])) {
        return autoComplete(req, currentCheckerSchema(input), prefix);
      }
      return autoCompleteKeywords(prefix);
  }
  
  
  registerContributions(TYPHONQL, {
    outliner(scriptOutliner),
    popup(menu("TyphonQL", actions)),
    annotator(Tree (Tree inp) {
        return checkQL(inp, currentCheckerSchema(inp));
    }),
    // [a-z A-Z][a-z A-Z 0-9 _]
    proposer(completer, "._$#@" + chars("a", "z") + chars("A", "Z") + chars("0", "9")),
    treeProperties(hasQuickFixes = false)
  }); 
  
  
}

str chars(str from, str to) 
    = stringChars([c | c <- [chars(from)[0]..chars(to)[0]]]);

set[str] KEYWORDS = {"select", "from", "where", "insert", "delete", "update", "set", "#polygon", "#point", "#blob", "#join", "true", "false"};

list[CompletionProposal] autoCompleteKeywords(str prefix) {
    result = [];
    for (k <- KEYWORDS, startsWith(k, toLowerCase(prefix))) {
        result += sourceProposal(k);
    }
    return result;
}

list[CompletionProposal] autoComplete(Tree input, CheckerMLSchema sc, str prefix) {
    result = autoCompleteKeywords(prefix);
    
    if ([str base, str field] := split(".", prefix + " ")) {
        field = trim(field);
        if (startsWith("@id", field)) {
            result += sourceProposal("<base>.@id");
        }
        else if (/(Binding)`<EId entity> <VId var>` := input, "<var>" == base) {
            for (f <- sc.fields[entityType("<entity>")], startsWith(f, field)) {
                result += sourceProposal("<base>.<f>");
            }
        }
    }
    else if (prefix != "") {
        for (tp <- sc.fields, startsWith(tp.name, prefix)) {
            result += sourceProposal(tp.name);
        }
    }
    return result;
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
