module lang::ecore::IO

import lang::ecore::Ecore;
import lang::ecore::Refs;
import util::Maybe;

@doc{Load a model resource `uri` and "parse" it according to `meta`.}
&T<:node load(type[&T<:node] meta, loc uri) = load(meta, uri, uri);


@doc{Load a model resource `uri` and "parse" it according to `meta`.
The parameter `refBase` will be used as the base of identities.} 
@javaClass{lang.ecore.bridge.IO}
java &T<:node load(type[&T<:node] meta, loc uri, loc refBase);


@doc{Load an Ecore meta model (an EPackage), identified by its `pkgURI` with which it's registered.}
@javaClass{lang.ecore.bridge.IO}
java EPackage load(loc pkgURI, type[EPackage] ecore = #EPackage);

@doc{Save a model to resource `uri`. pkgURI is used to obtain the meta model from the registry.}
@javaClass{lang.ecore.bridge.IO}
java void save(type[&T<:node] meta, &T<:node model, loc uri, loc pkgURI);

//@javaClass{lang.ecore.bridge.IO}
//@reflect{Needs the evaluator to call closures}
//java void(Patch) modelEditor(loc uri, type[Patch] pt = #Patch);
//
//@javaClass{lang.ecore.bridge.IO}
//@reflect{Needs the evaluator to call closures}
//java void(lrel[loc,str]) termEditor(loc src);
//
//
//@javaClass{lang.ecore.bridge.IO}
//@reflect{Needs the evaluator to call closures}
//java void observeEditor(type[&T<:node] meta, loc uri, void(&T<:node) callback);
//
//
//
//@doc{Obtain a function to directly patch an editor.}
//void(Patch) patcher(type[&T<:node] meta, loc uri) {
//  ed = editor(meta, uri); 
//  return void(Patch p) {
//    ed(Patch(&T<:node ignored) {
//      return p;
//    });
//  };
//}
//




