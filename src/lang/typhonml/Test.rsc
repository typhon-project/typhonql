module lang::typhonml::Test

import lang::typhonml::TyphonML;
import lang::ecore::Refs;
import lang::ecore::IO;

public loc ECOMMERCE = |project://it.univaq.disim.typhonml/model/TyphonECommerceExample.xmi|;

void smokeTest() {
  Model m = load(#Model, ECOMMERCE);
  

}