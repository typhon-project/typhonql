module lang::typhonml::Util


import lang::typhonml::TyphonML;

/*
 Consistency checks (for TyphonML)
  - Containment can not be many-to-many (IOW: target of containment with opposite should be [1]) 
*/

alias Rels = rel[str from, Cardinality fromCard, str fromRole, str toRole, Cardinality toCard, str to, bool containment];



 