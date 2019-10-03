module lang::typhonml::TyphonIO

import lang::ecore::Ecore;
import lang::ecore::Refs;

import util::Maybe;

@doc{Load a model resource from input `input` and "parse" it according to `meta` .
The parameter `refBase` will be used as the base of identities.
The Ecore package that is assumed is the one corresponding to TyphonML.} 
@javaClass{lang.typhonml.TyphonIO}
@reflect
java &T<:node loadTyphon(type[&T<:node] meta, str input, loc refBase);
