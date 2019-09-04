module lang::typhonql::IDE


import lang::typhonml::TyphonML;
import lang::typhonml::Util;

import lang::typhonql::TDBC;
import lang::typhonql::WorkingSet;
import lang::typhonql::Run;

import lang::ecore::IO;

import util::IDE;
import util::Prompt;
import util::ValueUI;
import ParseTree;
import IO;


@javaClass{nl.cwi.swat.typhonql.TyphonQL}
java Model bootTyphonQL(type[Model] model, loc pathToTML);


private str TYPHONQL = "TyphonQL";

void setupIDE() {
  Schema schema = schema({}, {}); // empty 
  
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
      loc modelLoc = |project://typhonql/<s.top.model>|;
      try {
        schema = loadSchema(modelLoc);
      }
      catch value v: {
        return {error("Error loading schema: <v>", s@\loc)};
      }
      return {};
    }),
    outliner(scriptOutliner),
    popup(menu("TyphonQL", [
      action("Execute",  void (Tree tree, loc selection) {
        if (treeFound(Request req) := treeAt(#Request, selection, tree)) {
          value result = run(req, schema);
          if (WorkingSet ws := result) {
            text(ws);
          }
          else {
            println(result);
          }
        }
      }),
      action("Dump schema",  void (Tree tree, loc selection) {
        dumpSchema(schema);
      }),
      action("Dump database",  void (Tree tree, loc selection) {
        text(dumpDB(schema));
      }),
      action("Reset database...", void (Tree tree, loc selection) {
        str yes = prompt("Are you sure to reset the polystore? (type \'yes\' to confirm)");
        if (yes == "yes") {
          runSchema(schema);
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

