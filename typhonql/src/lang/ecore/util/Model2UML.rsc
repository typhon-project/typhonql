module lang::ecore::util::Model2UML

import salix::lib::UML;

import lang::ecore::Ecore;
import lang::ecore::EcoreUtil;
import lang::ecore::Refs;
import lang::ecore::diff::Diff;

import salix::App;
import salix::Core;
import salix::HTML;

import Type;
import Node;
import IO;
import List;

App[&T<:node] modelApp(type[&T<:node] meta, &T<:node model) 
  = app(&T<:node() { return model; }, 
      viewer(meta), update, |http://localhost:9121/index.html|, |project://salix/src|); 
    
&T<:node update(Msg msg, &T<:node m) = m;

void(&T<:node) viewer(type[&T<:node] meta) {
  return void(&T<:node model) {
	  div(() {
	    div(uml2svgNode(model2plantUML(meta, model)));
	  });
  };
}

str model2plantUML(type[&T<:node] meta, &T<:node model) {
  str s = "@startuml\n";
  map[Id, int] ids = ();
  int id = 0;
  
  str makeName(int n) = "o<n>";

  void declareObj(str class, Id myId) {
    if (myId in ids) {
      return;
    }
    ids[myId] = id;
    s += "object \"<makeName(id)>: <class>\" as <makeName(id)>\n";
    id += 1;
  }
  
  top-down visit (model) {
    case node x: 
      if(!isInjection(x), Id myId := x.uid) {
        declareObj(getClass(x), myId);
      }
  }
  
  // special case for external Ecore things
  for (/Ref[EClassifier] r := model, isEcoreRef(r)) {
    declareObj(ecoreRefClassifierName(r), r.uid);    
  }
  
  void field2decl(int myId, str name, value val) {
    switch (val) {
      case ref(Id trg):  {
        s += "<makeName(ids[trg])> \<-- \"<name>\" <makeName(myId)>\n";
      }
      case node n: {
        if (isObj(n), node x := uninject(n), Id trg := x.uid) {
          s += "<makeName(myId)> *-- \"<name>\" <makeName(ids[trg])>\n";
        }
        else {
          throw "Bad node: <n>";
        }
      }
      case list[value] vs: {
        for (value v <- vs) {
          field2decl(myId, name, v);
        }
      }
      case str v: 
        s += "<makeName(myId)> : <name> = \"<v>\"\n";
      case value v: 
        s += "<makeName(myId)> : <name> = <v>\n";
    }
  }
  
  s += "\n";
  
  for (/node x := model, !isInjection(x), Id myId := x.uid) {
    for (<str name, value val> <- zip(getParams(meta, typeOf(x), getName(x)), getChildren(x))) {
      field2decl(ids[myId], name, val);    
    }
     
    kws = getKeywordParameters(x);
    for (str name <- kws, name != "uid") {
      field2decl(ids[myId], name, kws[name]);
    }
  }
  
  
  s += "@enduml\n";
  return s;
}



