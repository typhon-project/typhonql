module lang::typhonql::WorkingSet

alias WorkingSet
  = map[str entity, list[Entity] entities];


// values starting with # and being 37 chars long are 
// interpreted as UUID references   
alias Entity
  = tuple[str name, str uuid, map[str, value] fields];

  
// TODO: write pp function that produces parseable object notation
// provide IDE support for it (hyperlinking)
// and then when execute, open editor for it instead of console. 