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


@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java Model bootTyphonQL(type[Model] model, loc pathToTML);

@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java str readHttpLocation(loc pathToResource);


private str TYPHONQL = "TyphonQL";

Schema getSchema(start[Script] s) {
	lo = toLocation("<s.top.model>");
	println(lo);
	//try{
		if (lo.scheme == "http") {
			str modelStr = readHttpLocation(lo);
			Schema sch = loadTyphonMLSchema(lo, modelStr);
			return sch;
		}
		else {
			loc modelLoc = |project://typhonql/src/lang/typhonml/mydb4.xmi|;
			Schema sch = loadSchema(modelLoc);
			return sch;
		}
		
	/*} catch value v:{
		println(v);
		return schema({}, {});
	}*/
}

void setupIDE() {
  map[loc, Schema] schemas = (); // empty 
  
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
      	println(s@\loc);
        schemas += (s@\loc : getSchema(s));
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
          sch = schemas[tree@\loc];
          value result = run(req, sch);
          if (WorkingSet ws := result) {
            text(ws);
          }
          else {
            println(result);
          }
        }
      }),
      action("Dump schema",  void (Tree tree, loc selection) {
        sch = schemas[tree@\loc];
        println(tree@\loc);
        println("About to print schema");
        dumpSchema(sch);
      }),
      action("Dump database",  void (Tree tree, loc selection) {
      	sch = schemas[tree@\loc];
        text(dumpDB(sch));
      }),
      action("Reset database...", void (Tree tree, loc selection) {
      	sch = schemas[tree@\loc];
        str yes = prompt("Are you sure to reset the polystore? (type \'yes\' to confirm)");
        if (yes == "yes") {
          runSchema(sch);
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

