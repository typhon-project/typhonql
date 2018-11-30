module lang::ladon::Query

extend lang::ladon::Expr;

syntax Query
  = "from" {Binding ","}+ bindings "select" {Expr ","}+ selected Where?
  ;

syntax Binding = EId entity VId var;
  
syntax Where = "where" {Expr ","}+ clauses;

  