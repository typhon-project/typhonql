module lang::typhonql::IDE


import lang::typhonml::TyphonML;
import lang::typhonml::Util;

import lang::typhonql::TDBC;
import lang::typhonql::WorkingSet;
import lang::typhonql::Run;

import util::IDE;
import util::Prompt;
import util::ValueUI;
import ParseTree;
import IO;
import String;

import util::Reflective;
import lang::manifest::IO;

// TODO do the parsing of JSon containing meta information in Rascal
alias ConnectionInfo = tuple[str dbType, str host, int port, str dbName, str user, str password];

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java Model bootTyphonQL(type[Model] model, loc pathToTML);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java Model bootConnections(loc polystoreUri, str user, str password);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java str readHttpModel(loc polystoreUri, str user, str password);


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

loc buildPolystoreUri(TyphonQLManifest typhonConf) 
	= |http://<typhonConf.PolystoreHost>:<typhonConf.PolystorePort>|;

Schema getSchema(loc polystoreUri, str user, str password) {
	str modelStr = readHttpModel(polystoreUri, user, password);
	Schema sch = loadTyphonMLSchema(polystoreUri, modelStr);
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

void setupIDE() {
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
  
  
  registerContributions(TYPHONQL, {
    builder(set[Message] (start[Script] s) {
      //try {
      	//Model m = bootTyphonQL(#Model, |tmp:///|);
      	TyphonQLManifest typhonConf = readTyphonConfig(s@\loc);
      	loc polystoreUri = buildPolystoreUri(typhonConf);
      	bootConnections(polystoreUri, typhonConf.PolystoreUser, typhonConf.PolystorePassword);
        sch = getSchema(polystoreUri, typhonConf.PolystoreUser, typhonConf.PolystorePassword);
      /*}
      catch value v: {
        return {error("Error loading schema: <v>", s@\loc)};
      }*/
      return {};
    }),
    outliner(scriptOutliner),
    popup(menu("TyphonQL", [
      action("Execute",  void (Tree tree, loc selection) {
        if (treeFound(Request req) := treeAt(#Request, selection, tree)) {
          TyphonQLManifest typhonConf = readTyphonConfig(tree@\loc);
      	  loc polystoreUri = buildPolystoreUri(typhonConf);
          value result = run(req, "<polystoreUri>", sch);
          if (WorkingSet ws := result) {
            text(ws);
          }
          else {
            println(result);
          }
        }
      }),
      action("Dump schema",  void (Tree tree, loc selection) {
        println(tree@\loc);
        println("About to print schema");
        TyphonQLManifest typhonConf = readTyphonConfig(tree@\loc);
      	loc polystoreUri = buildPolystoreUri(typhonConf);
        dumpSchema(sch, typhonConf.PolystoreUser, typhonConf.PolystorePassword);
      }),
      action("Dump database",  void (Tree tree, loc selection) {
      	TyphonQLManifest typhonConf = readTyphonConfig(tree@\loc);
      	loc polystoreUri = buildPolystoreUri(typhonConf);
      	sch = schemas[polystoreUri];
      	text(dumpDB("<polystoreUri>", sch));
      }),
      action("Reset database...", void (Tree tree, loc selection) {
      	str yes = prompt("Are you sure to reset the polystore? (type \'yes\' to confirm)");
        if (yes == "yes") {
          TyphonQLManifest typhonConf = readTyphonConfig(tree@\loc);
          loc polystoreUri = buildPolystoreUri(typhonConf);
          runSchema("<polystoreUri>", sch);
        }
      })
      
    ]))
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
     ""(""()[@label="<script.top.model>"])[@label="Model"][@\loc=script.top.model@\loc],
     ""([
       ""(selects)[@label="Selects"],
       ""(inserts)[@label="Inserts"],
       ""(updates)[@label="Updates"],
       ""(deletes)[@label="Deletes"]
     ])[@label="Requests"]
   ];
   return "outline"([sections])[@label="Script"];
    
}

